# Supplies lent (fertilizer, tools...) in loans given in the period: which,
# how much, to whom and what they are worth.
class LoanSuppliesReport < Report
  NAME = "people.first_names || ' ' || people.last_names".freeze

  self.module_key = "loans"
  self.date_column = "loans.disbursed_on"
  self.default_period = "this_season"
  self.default_sort = :disbursed_on
  self.default_measure = :total

  filter :q, :text
  filter :supply_id, :id

  detail { |item| loans_loan_path(item.loan) }

  column(:disbursed_on, :date, sort: "loans.disbursed_on") { |item| item.loan.disbursed_on }
  column(:person, :text, sort: "people.last_names") { |item| item.loan.person.full_name }
  column(:loan, :text, sort: "loan_supplies.loan_id", priority: 3) { |item| "#{Loan.model_name.human} #{item.loan_id}" }
  column(:supply, :text, sort: "supplies.name") { |item| item.supply.name }
  column(:quantity, :text, sort: "loan_supplies.quantity", priority: 2) do |item|
    "#{ActiveSupport::NumberHelper.number_to_rounded(item.quantity, precision: 2, strip_insignificant_zeros: true, delimiter: ",")} #{item.supply.unit}"
  end
  column(:unit_price, :money, sort: "loan_supplies.unit_price", priority: 3)
  column(:total, :money, sort: "loan_supplies.total")

  measure :count, :integer, "COUNT(*)"
  measure :total, :money, "SUM(loan_supplies.total)"
  measure :loans, :integer, "COUNT(DISTINCT loan_supplies.loan_id)"
  measure :people, :integer, "COUNT(DISTINCT loans.person_id)"

  group :month, unit: "month"
  group :supply, sql: "loan_supplies.supply_id", label_sql: "MIN(supplies.name || ' (' || supplies.unit || ')')"
  group :person, sql: "loans.person_id", label_sql: "MIN(#{NAME})"

  kpi :total, :money, "SUM(loan_supplies.total)"
  kpi :count, :integer, "COUNT(*)"
  kpi :supplies, :integer, "COUNT(DISTINCT loan_supplies.supply_id)"
  kpi :people, :integer, "COUNT(DISTINCT loans.person_id)"

  def scope
    LoanSupply.joins(:supply, loan: :person)
  end

  def apply_filters(relation)
    relation = relation.where(loans: { person_id: people_matching(filter.q) }) if filter.q
    relation = relation.where(supply_id: filter.supply_id) if filter.supply_id
    relation
  end

  def charts
    relation = records
    supplies = breakdown(relation, "loan_supplies.supply_id", "SUM(loan_supplies.total)", label_sql: "MIN(supplies.name)")
    quantities = breakdown(relation, "loan_supplies.supply_id", "SUM(loan_supplies.quantity)",
                           label_sql: "MIN(supplies.name || ' (' || supplies.unit || ')')", others: false)
    labels, by_supply = over_time_by(relation, "loan_supplies.supply_id", "SUM(loan_supplies.total)", label_sql: "MIN(supplies.name)")
    people = breakdown(relation, "loans.person_id", "SUM(loan_supplies.total)", label_sql: "MIN(#{NAME})", limit: 10, others: false)

    [
      chart(:value_by_supply, :doughnut, labels: supplies.map(&:first), datasets: [ dataset(:total, supplies.map(&:last), format: :money) ]),
      chart(:quantities, :hbar, labels: quantities.map(&:first), datasets: [ dataset(:quantity, quantities.map(&:last), format: :number) ]),
      chart(:over_time, :stacked, labels:, datasets: by_supply.map { |set| set.merge(format: :money) }, wide: true),
      chart(:people, :hbar, labels: people.map(&:first), datasets: [ dataset(:total, people.map(&:last), format: :money) ])
    ]
  end

  private
    def preload(relation) = relation.includes(:supply, loan: :person)
end
