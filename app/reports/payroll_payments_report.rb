# Payroll payments made in the period (by date of payment), by farm and
# payroll: what the members earned, what went to their loans and what was
# handed out, next to the payrolls' expenses.
class PayrollPaymentsReport < Report
  LINES = <<~SQL.squish.freeze
    LEFT JOIN (SELECT payroll_payment_id, COUNT(*) AS members FROM payroll_payment_lines GROUP BY payroll_payment_id) line_counts
      ON line_counts.payroll_payment_id = payroll_payments.id
  SQL

  self.module_key = "farms"
  self.date_column = "payroll_payments.paid_on"
  self.default_period = "this_month"
  self.default_sort = :paid_on
  self.default_measure = :gross_total

  filter :farm_id, :id
  filter :payroll_id, :id
  filter :kind, :choice, in: Payroll::KINDS

  detail { |payment| farms_payroll_payment_path(payment.payroll, payment) }

  column(:paid_on, :date, sort: "payroll_payments.paid_on")
  column(:farm, :text, sort: "farms.name", priority: 2) { |payment| payment.payroll.farm.name }
  column(:payroll, :text, sort: "payrolls.name") { |payment| payment.payroll.name }
  column(:kind, :text, sort: "payrolls.kind", priority: 3) { |payment| payment.payroll.human_kind }
  column(:period, :text, sort: "payroll_payments.period_starts_on", priority: 3) do |payment|
    I18n.t("farms.period", from: I18n.l(payment.period_starts_on, format: :short), to: I18n.l(payment.period_ends_on, format: :short))
  end
  column(:members, :integer, sort: "line_counts.members", priority: 3) { |payment| payment.members.to_i }
  column(:gross_total, :money, sort: "payroll_payments.gross_total")
  column(:loans_total, :money, sort: "payroll_payments.loans_total", priority: 2)
  column(:net_total, :money, sort: "payroll_payments.net_total", priority: 2)

  measure :count, :integer, "COUNT(*)"
  measure :members, :integer, "COALESCE(SUM(line_counts.members), 0)"
  measure :gross_total, :money, "SUM(payroll_payments.gross_total)"
  measure :loans_total, :money, "SUM(payroll_payments.loans_total)"
  measure :net_total, :money, "SUM(payroll_payments.net_total)"

  group :week, unit: "week"
  group :month, unit: "month"
  group :farm, sql: "payrolls.farm_id", label_sql: "MIN(farms.name)"
  group :payroll, sql: "payroll_payments.payroll_id", label_sql: "MIN(payrolls.name || ' · ' || farms.name)"
  group :kind, sql: "payrolls.kind", translate: ->(kind) { Payroll.human_attribute_name("kind/#{kind}") }

  kpi :count, :integer, "COUNT(*)"
  kpi :gross_total, :money, "SUM(payroll_payments.gross_total)", good: :down
  kpi :loans_total, :money, "SUM(payroll_payments.loans_total)"
  kpi :net_total, :money, "SUM(payroll_payments.net_total)", good: :down
  kpi(:expenses, :money, good: :down) { |_, in_period| expenses_for(in_period).sum(:amount) }
  kpi(:total_cost, :money, good: :down) { |relation, in_period| relation.sum(:gross_total) + expenses_for(in_period).sum(:amount) }

  def scope
    PayrollPayment.joins(payroll: :farm).joins(LINES)
  end

  def apply_filters(relation)
    relation = relation.where(payrolls: { farm_id: filter.farm_id }) if filter.farm_id
    relation = relation.where(payroll_id: filter.payroll_id) if filter.payroll_id
    relation = relation.where(payrolls: { kind: filter.kind }) if filter.kind
    relation
  end

  def charts
    relation = records
    labels, by_farm = over_time_by(relation, "payrolls.farm_id", "SUM(payroll_payments.gross_total)", label_sql: "MIN(farms.name)")
    kinds = breakdown(relation, "payrolls.kind", "SUM(payroll_payments.gross_total)", translate: human(Payroll, :kind))
    costs = farm_costs(relation)
    member_labels, people = over_time(relation, { gross: "SUM(payroll_payments.gross_total)", members: "SUM(line_counts.members)" })

    [
      chart(:by_farm, :stacked, labels:, datasets: by_farm.map { |set| set.merge(format: :money) }, wide: true),
      chart(:farm_costs, :stacked, labels: costs.keys, datasets: [ dataset(:payrolls, costs.values.map(&:first), format: :money),
                                                                  dataset(:expenses, costs.values.map(&:last), format: :money) ]),
      chart(:kinds, :doughnut, labels: kinds.map(&:first), datasets: [ dataset(:gross_total, kinds.map(&:last), format: :money) ]),
      chart(:members, :combo, labels: member_labels, datasets: [ dataset(:gross_total, people[:gross], format: :money),
                                                                 dataset(:members, people[:members], format: :integer, kind: :line, axis: :y2) ],
                              wide: true),
      locations(:map, relation, place: :farm, measure: :gross_total, sql: "SUM(payroll_payments.gross_total)", format: :money,
                                link: :farms_farm_path, link_sql: "farms.id")
    ]
  end

  private
    def preload(relation)
      relation.includes(payroll: :farm).select("payroll_payments.*", "line_counts.members")
    end

    # Expenses of the payrolls the filters pick (farm, payroll, kind) in a
    # period, by date of expense.
    def expenses_for(in_period)
      payrolls = Payroll.all
      payrolls = payrolls.where(farm_id: filter.farm_id) if filter.farm_id
      payrolls = payrolls.where(id: filter.payroll_id) if filter.payroll_id
      payrolls = payrolls.where(kind: filter.kind) if filter.kind
      expenses = PayrollExpense.where(payroll_id: payrolls.select(:id))
      range = in_period.range
      expenses = expenses.where(spent_on: range.begin..) if range&.begin
      expenses = expenses.where(spent_on: ..range.end) if range&.end
      expenses
    end

    # Payroll cost by farm: { name => [paid (gross), expenses] }.
    def farm_costs(relation)
      paid = plain(relation).group("farms.name").sum(:gross_total)
      spent = expenses_for(period).joins(payroll: :farm).group("farms.name").sum(:amount)
      (paid.keys | spent.keys).sort.to_h { |name| [ name, [ number(paid[name]), number(spent[name]) ] ] }
    end
end
