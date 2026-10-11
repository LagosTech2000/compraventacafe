# What each employee was paid, line by line of the payroll payments of the
# period: days, cans or tasks, what they earned, what went to their loans
# and what they were handed.
class PayrollLinesReport < Report
  NAME = "people.first_names || ' ' || people.last_names".freeze

  self.module_key = "farms"
  self.date_column = "payroll_payments.paid_on"
  self.default_period = "this_month"
  self.default_sort = :paid_on
  self.default_measure = :gross_amount

  filter :q, :text
  filter :farm_id, :id
  filter :payroll_id, :id
  filter :basis, :choice, in: Payroll::KINDS

  detail { |line| farms_payroll_payment_path(line.payment.payroll, line.payment) }

  column(:paid_on, :date, sort: "payroll_payments.paid_on") { |line| line.payment.paid_on }
  column(:person, :text, sort: "people.last_names") { |line| line.member.full_name }
  column(:farm, :text, sort: "farms.name", priority: 3) { |line| line.payment.payroll.farm.name }
  column(:payroll, :text, sort: "payrolls.name", priority: 2) { |line| line.payment.payroll.name }
  column(:basis, :text, sort: "payroll_payment_lines.basis", priority: 3) do |line|
    I18n.t("reports.types.payroll_lines.bases.#{line.basis}")
  end
  column(:quantity, :text, sort: "payroll_payment_lines.quantity", priority: 2) do |line|
    amount = ActiveSupport::NumberHelper.number_to_rounded(line.quantity, precision: 2, strip_insignificant_zeros: true)
    "#{amount} #{I18n.t("farms.units.#{line.basis}", count: line.quantity.to_d == 1 ? 1 : 2)}"
  end
  column(:gross_amount, :money, sort: "payroll_payment_lines.gross_amount")
  column(:loans_amount, :money, sort: "payroll_payment_lines.loans_amount", priority: 2)
  column(:net_amount, :money, sort: "payroll_payment_lines.net_amount", priority: 2)

  measure :people, :integer, "COUNT(DISTINCT payroll_members.person_id)"
  measure :days, :number, "COALESCE(SUM(payroll_payment_lines.quantity) FILTER (WHERE payroll_payment_lines.basis = 'daily'), 0)"
  measure :cans, :number, "COALESCE(SUM(payroll_payment_lines.quantity) FILTER (WHERE payroll_payment_lines.basis = 'harvest'), 0)"
  measure :gross_amount, :money, "SUM(payroll_payment_lines.gross_amount)"
  measure :loans_amount, :money, "SUM(payroll_payment_lines.loans_amount)"
  measure :net_amount, :money, "SUM(payroll_payment_lines.net_amount)"

  group :person, sql: "payroll_members.person_id", label_sql: "MIN(#{NAME})"
  group :farm, sql: "payrolls.farm_id", label_sql: "MIN(farms.name)"
  group :payroll, sql: "payroll_payments.payroll_id", label_sql: "MIN(payrolls.name || ' · ' || farms.name)"
  group :basis, sql: "payroll_payment_lines.basis", translate: ->(basis) { I18n.t("reports.types.payroll_lines.bases.#{basis}") }
  group :month, unit: "month"

  kpi :people, :integer, "COUNT(DISTINCT payroll_members.person_id)"
  kpi :gross_amount, :money, "SUM(payroll_payment_lines.gross_amount)"
  kpi :loans_amount, :money, "SUM(payroll_payment_lines.loans_amount)"
  kpi :net_amount, :money, "SUM(payroll_payment_lines.net_amount)"
  kpi :average, :money, "SUM(payroll_payment_lines.gross_amount) / NULLIF(COUNT(DISTINCT payroll_members.person_id), 0)"
  kpi :days, :number, "COALESCE(SUM(payroll_payment_lines.quantity) FILTER (WHERE payroll_payment_lines.basis = 'daily'), 0)"

  def scope
    PayrollPaymentLine.joins(payment: { payroll: :farm }).joins(member: :person)
  end

  def apply_filters(relation)
    relation = relation.where(payroll_members: { person_id: people_matching(filter.q) }) if filter.q
    relation = relation.where(payrolls: { farm_id: filter.farm_id }) if filter.farm_id
    relation = relation.where(payroll_payments: { payroll_id: filter.payroll_id }) if filter.payroll_id
    relation = relation.where(basis: filter.basis) if filter.basis
    relation
  end

  def charts
    relation = records
    top = breakdown(relation, "payroll_members.person_id", "SUM(payroll_payment_lines.gross_amount)", label_sql: "MIN(#{NAME})",
                                                                                                    limit: 15, others: false)
    bases = breakdown(relation, "payroll_payment_lines.basis", "SUM(payroll_payment_lines.gross_amount)",
                      translate: ->(basis) { I18n.t("reports.types.payroll_lines.bases.#{basis}") })
    labels, by_farm = over_time_by(relation, "payrolls.farm_id", "SUM(payroll_payment_lines.gross_amount)", label_sql: "MIN(farms.name)")

    [
      chart(:top, :hbar, labels: top.map(&:first), datasets: [ dataset(:gross_amount, top.map(&:last), format: :money) ], wide: true),
      chart(:bases, :doughnut, labels: bases.map(&:first), datasets: [ dataset(:gross_amount, bases.map(&:last), format: :money) ]),
      chart(:by_farm, :stacked, labels:, datasets: by_farm.map { |set| set.merge(format: :money) })
    ]
  end

  private
    def preload(relation) = relation.includes(member: :person, payment: { payroll: :farm })
end
