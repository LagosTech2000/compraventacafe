# Each farm with what it produced and what it cost in the period (Fernando,
# 2026-10-14): the coffee bought from it (QQ and money), the cans picked in
# its harvest payrolls, what its payrolls paid and its expenses, and, with
# its land written (FarmArea), the same per manzana and per hectare. The
# period narrows those figures, not the farms. Crosses Compra de café and
# Fincas, so it needs both.
class FarmsReport < Report
  OWNERS = %w[business producers].freeze
  QUINTAL = PurchaseCalculation::QUINTAL_WEIGHT
  MANZANAS = FarmArea.sql_in("manzana")
  HECTARES = FarmArea.sql_in("hectare")
  QUINTALS = "(COALESCE(sales.net_weight, 0) / #{QUINTAL})".freeze
  COST = "(COALESCE(paid.amount, 0) + COALESCE(spent.amount, 0))".freeze
  BALANCE = "(COALESCE(sales.total, 0) - #{COST})".freeze
  ACTIVITY = "(sales.purchases_count IS NOT NULL OR picked.cans IS NOT NULL OR paid.amount IS NOT NULL OR spent.amount IS NOT NULL)".freeze
  OWNER = "COALESCE(people.first_names || ' ' || people.last_names, '')".freeze

  self.module_key = "farms"
  self.date_column = "purchases.purchased_at"
  self.date_type = :datetime
  self.default_period = "this_season"
  self.default_sort = :quintals
  self.default_measure = :quintals

  filter :q, :text
  filter :owner, :choice, in: OWNERS
  filter :activity, :choice, in: %w[with_activity], default: "with_activity"

  def self.module_keys = %w[farms trading]

  detail { |farm| farms_farm_path(farm) }

  column(:farm, :text, sort: "farms.name", &:name)
  column(:owner, :text, sort: OWNER, priority: 3) { |farm| farm.producer&.full_name || I18n.t("reports.types.farms.business") }
  column(:manzanas, :number, sort: MANZANAS, priority: 2) { |farm| farm.area&.manzanas }
  column(:hectares, :number, sort: HECTARES, priority: 3) { |farm| farm.area&.hectares }
  column(:quintals, :quintals, sort: QUINTALS) { |farm| farm.sales_net_weight.to_d / QUINTAL }
  column(:sales_total, :money, sort: "sales.total", priority: 2) { |farm| farm.sales_total.to_d }
  column(:cans, :number, sort: "picked.cans", priority: 3) { |farm| farm.picked_cans }
  column(:cost, :money, sort: COST, priority: 2) { |farm| farm.paid_amount.to_d + farm.spent_amount.to_d }
  column(:balance, :money, sort: BALANCE) { |farm| farm.sales_total.to_d - farm.paid_amount.to_d - farm.spent_amount.to_d }
  column(:quintals_per_manzana, :quintals, sort: "#{QUINTALS} / NULLIF(#{MANZANAS}, 0)", priority: 2) do |farm|
    farm.sales_net_weight.to_d / QUINTAL / farm.area.manzanas if farm.area
  end
  column(:quintals_per_hectare, :quintals, sort: "#{QUINTALS} / NULLIF(#{HECTARES}, 0)", priority: 3) do |farm|
    farm.sales_net_weight.to_d / QUINTAL / farm.area.hectares if farm.area
  end
  column(:cost_per_quintal, :money, sort: "#{COST} / NULLIF(#{QUINTALS}, 0)", priority: 3) do |farm|
    quintals = farm.sales_net_weight.to_d / QUINTAL
    (farm.paid_amount.to_d + farm.spent_amount.to_d) / quintals if quintals.positive?
  end

  measure :farms, :integer, "COUNT(*)"
  measure :manzanas, :number, "COALESCE(SUM(#{MANZANAS}), 0)"
  measure :quintals, :quintals, "SUM(#{QUINTALS})"
  measure :sales_total, :money, "COALESCE(SUM(sales.total), 0)"
  measure :cans, :number, "COALESCE(SUM(picked.cans), 0)"
  measure :cost, :money, "SUM(#{COST})"
  measure :balance, :money, "SUM(#{BALANCE})"

  group :owner_kind, sql: "CASE WHEN farms.producer_id IS NULL THEN 'business' ELSE 'producers' END",
                     translate: ->(owner) { I18n.t("reports.filters.farm_owners.#{owner}") }
  group :producer, sql: "farms.producer_id", label_sql: "MIN(#{OWNER})"
  group :department, sql: "farms.department_id", label_sql: "MIN(departments.name)"

  kpi :quintals, :quintals, "SUM(#{QUINTALS})", good: :up
  kpi :sales_total, :money, "COALESCE(SUM(sales.total), 0)", good: :up
  kpi :cost, :money, "SUM(#{COST})", good: :down
  kpi :balance, :money, "SUM(#{BALANCE})", good: :up
  # Only the farms with their land written count, in both terms.
  kpi :quintals_per_manzana, :quintals,
      "SUM(#{QUINTALS}) FILTER (WHERE farms.area_value IS NOT NULL) / NULLIF(SUM(#{MANZANAS}), 0)", good: :up
  kpi :cans, :number, "COALESCE(SUM(picked.cans), 0)", good: :up

  def scope = Farm.all

  def records(in_period = period)
    relation = Farm.left_joins(:department).joins("LEFT JOIN producers ON producers.id = farms.producer_id")
                   .joins("LEFT JOIN people ON people.id = producers.person_id")
                   .joins(join(:sales, sales(in_period))).joins(join(:picked, picked(in_period)))
                   .joins(join(:paid, paid(in_period))).joins(join(:spent, spent(in_period)))
    apply_filters(relation)
  end

  def apply_filters(relation)
    relation = relation.where("farms.name ILIKE ?", like(filter.q)) if filter.q
    relation = relation.where(producer_id: nil) if filter.owner == "business"
    relation = relation.where.not(producer_id: nil) if filter.owner == "producers"
    relation = relation.where(ACTIVITY) if filter.activity
    relation
  end

  def charts
    with_area = records.where.not(area_value: nil)
    per_manzana = plain(with_area).where("#{QUINTALS} > 0").order(Arel.sql("#{QUINTALS} / NULLIF(#{MANZANAS}, 0) DESC")).limit(15)
                                  .pluck(Arel.sql("farms.name"), Arel.sql("#{QUINTALS} / NULLIF(#{MANZANAS}, 0)"))
    money = plain(records).order(Arel.sql("GREATEST(COALESCE(sales.total, 0), #{COST}) DESC")).limit(15)
                          .pluck(Arel.sql("farms.name"), Arel.sql("COALESCE(sales.total, 0)"), Arel.sql(COST), Arel.sql(BALANCE))
    quintals = breakdown(records, "farms.id", "SUM(#{QUINTALS})", label_sql: "MIN(farms.name)", limit: 10)

    [
      chart(:per_manzana, :hbar, labels: per_manzana.map(&:first),
                                 datasets: [ dataset(:quintals_per_manzana, per_manzana.map { |row| number(row[1]) }, format: :quintals) ]),
      chart(:money, :bar, labels: money.map(&:first),
                          datasets: [ dataset(:sales_total, money.map { |row| number(row[1]) }, format: :money),
                                      dataset(:cost, money.map { |row| number(row[2]) }, format: :money),
                                      dataset(:balance, money.map { |row| number(row[3]) }, format: :money, kind: :line) ], wide: true),
      chart(:quintals, :doughnut, labels: quintals.map(&:first), datasets: [ dataset(:quintals, quintals.map(&:last), format: :quintals) ]),
      locations(:map, records, place: :farm, measure: :quintals, sql: "SUM(#{QUINTALS})", format: :quintals,
                               link: :farms_farm_path, link_sql: "farms.id")
    ]
  end

  private
    def preload(relation)
      relation.includes(producer: :person)
              .select("farms.*", "sales.net_weight AS sales_net_weight", "sales.total AS sales_total", "picked.cans AS picked_cans",
                      "paid.amount AS paid_amount", "spent.amount AS spent_amount")
    end

    def join(name, relation) = "LEFT JOIN (#{relation.to_sql}) #{name} ON #{name}.farm_id = farms.id"

    # The coffee bought from each farm (purchases that name it).
    def sales(in_period)
      within(Purchase.active.where.not(farm_id: nil), in_period, column: "purchases.purchased_at", type: :datetime)
        .group(:farm_id).select(:farm_id, "COUNT(*) AS purchases_count", "SUM(purchases.net_weight) AS net_weight",
                                "SUM(purchases.total) AS total")
    end

    # Cans picked in its harvest payrolls.
    def picked(in_period)
      within(HarvestEntry.joins("JOIN payroll_members ON payroll_members.id = harvest_entries.payroll_member_id")
                         .joins("JOIN payrolls ON payrolls.id = payroll_members.payroll_id"),
             in_period, column: "harvest_entries.worked_on")
        .group("payrolls.farm_id").select("payrolls.farm_id", "SUM(harvest_entries.cans) AS cans")
    end

    # What its payrolls paid (gross, before loan discounts).
    def paid(in_period)
      within(PayrollPayment.joins(:payroll), in_period, column: "payroll_payments.paid_on")
        .group("payrolls.farm_id").select("payrolls.farm_id", "SUM(payroll_payments.gross_total) AS amount")
    end

    def spent(in_period)
      within(PayrollExpense.joins(:payroll), in_period, column: "payroll_expenses.spent_on")
        .group("payrolls.farm_id").select("payrolls.farm_id", "SUM(payroll_expenses.amount) AS amount")
    end
end
