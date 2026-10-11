# Payments on loans ("abonos") in the period: how much came in, how much of
# it was interest and how much principal, and how it was paid (cash,
# transfer, check, with coffee or from a payroll).
class LoanPaymentsReport < Report
  METHODS = (LoanPayment::PAYMENT_METHODS + [ LoanPayment::COFFEE, LoanPayment::PAYROLL ]).freeze
  NAME = "people.first_names || ' ' || people.last_names".freeze

  self.module_key = "loans"
  self.date_column = "loan_payments.paid_on"
  self.default_period = "this_month"
  self.default_sort = :paid_on
  self.default_measure = :amount

  filter :q, :text
  filter :payment_method, :choice, in: METHODS
  filter :created_by_id, :id

  detail { |payment| loans_loan_payment_path(payment.loan, payment) }

  column(:paid_on, :date, sort: "loan_payments.paid_on")
  column(:receipt, :text, sort: "loan_payments.id", priority: 3, &:display_number)
  column(:person, :text, sort: "people.last_names") { |payment| payment.loan.person.full_name }
  column(:loan, :text, sort: "loan_payments.loan_id", priority: 3) { |payment| "#{Loan.model_name.human} #{payment.loan_id}" }
  column(:payment_method, :text, sort: "loan_payments.payment_method", priority: 2, &:human_payment_method)
  column(:amount, :money, sort: "loan_payments.amount")
  column(:interest_amount, :money, sort: "loan_payments.interest_amount", priority: 2)
  column(:principal_amount, :money, sort: "loan_payments.principal_amount", priority: 2)
  column(:created_by, :text, sort: "users.name", priority: 3) { |payment| payment.created_by.name }

  measure :count, :integer, "COUNT(*)"
  measure :amount, :money, "SUM(loan_payments.amount)"
  measure :interest_amount, :money, "SUM(loan_payments.interest_amount)"
  measure :principal_amount, :money, "SUM(loan_payments.principal_amount)"
  measure :people, :integer, "COUNT(DISTINCT loans.person_id)"

  group :day, unit: "day"
  group :week, unit: "week"
  group :month, unit: "month"
  group :payment_method, sql: "loan_payments.payment_method", translate: ->(method) { LoanPayment.human_attribute_name("payment_method/#{method}") }
  group :person, sql: "loans.person_id", label_sql: "MIN(#{NAME})"
  group :created_by, sql: "loan_payments.created_by_id", label_sql: "MIN(users.name)"

  kpi :count, :integer, "COUNT(*)", good: :up
  kpi :amount, :money, "SUM(loan_payments.amount)", good: :up
  kpi :interest_amount, :money, "SUM(loan_payments.interest_amount)", good: :up
  kpi :principal_amount, :money, "SUM(loan_payments.principal_amount)", good: :up
  kpi :coffee, :money, "COALESCE(SUM(loan_payments.amount) FILTER (WHERE loan_payments.payment_method = 'coffee'), 0)"
  kpi :payroll, :money, "COALESCE(SUM(loan_payments.amount) FILTER (WHERE loan_payments.payment_method = 'payroll'), 0)"

  def scope
    LoanPayment.joins(loan: :person).joins(:created_by)
  end

  def apply_filters(relation)
    relation = relation.where(loans: { person_id: people_matching(filter.q) }) if filter.q
    relation = relation.where(payment_method: filter.payment_method) if filter.payment_method
    relation = relation.where(created_by_id: filter.created_by_id) if filter.created_by_id
    relation
  end

  def charts
    relation = records
    labels, split = over_time(relation, { interest: "SUM(loan_payments.interest_amount)", principal: "SUM(loan_payments.principal_amount)" })
    methods = breakdown(relation, "loan_payments.payment_method", "SUM(loan_payments.amount)", translate: human(LoanPayment, :payment_method))
    payers = breakdown(relation, "loans.person_id", "SUM(loan_payments.amount)", label_sql: "MIN(#{NAME})", limit: 10, others: false)

    [
      chart(:split, :stacked, labels:, datasets: [ dataset(:interest, split[:interest], format: :money),
                                                   dataset(:principal, split[:principal], format: :money) ], wide: true),
      chart(:methods, :doughnut, labels: methods.map(&:first), datasets: [ dataset(:amount, methods.map(&:last), format: :money) ]),
      chart(:payers, :hbar, labels: payers.map(&:first), datasets: [ dataset(:amount, payers.map(&:last), format: :money) ])
    ]
  end

  private
    def preload(relation) = relation.includes(:created_by, loan: :person)
end
