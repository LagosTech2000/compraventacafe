# Each person and everything they have with the business in the period,
# across modules: coffee they sold (trading), what they earned in payrolls
# (farms), what they paid on loans and what they owe today (loans). Needs
# the read permission of the three modules.
class PeopleReport < Report
  ROLES = %w[producer client collaborator borrower employee].freeze
  ACTIVITIES = %w[with_activity].freeze
  QUINTAL = PurchaseCalculation::QUINTAL_WEIGHT
  ACTIVITY = "(sales.total IS NOT NULL OR earned.amount IS NOT NULL OR repaid.amount IS NOT NULL OR owed.amount > 0)".freeze
  OWED = <<~SQL.squish.freeze
    LEFT JOIN (
      SELECT loans.person_id, SUM(loans.principal - COALESCE(paid.principal, 0)) AS amount
      FROM loans LEFT JOIN (SELECT loan_id, SUM(principal_amount) AS principal FROM loan_payments GROUP BY loan_id) paid
        ON paid.loan_id = loans.id
      WHERE loans.paid_off_on IS NULL GROUP BY loans.person_id
    ) owed ON owed.person_id = people.id
  SQL
  PAID_TO_THEM = "(COALESCE(sales.total, 0) + COALESCE(earned.amount, 0))".freeze
  NAME = "people.first_names || ' ' || people.last_names".freeze
  ROLE_SQL = {
    "producer" => "EXISTS (SELECT 1 FROM producers WHERE producers.person_id = people.id)",
    "client" => "EXISTS (SELECT 1 FROM clients WHERE clients.person_id = people.id)",
    "collaborator" => "EXISTS (SELECT 1 FROM collaborators WHERE collaborators.person_id = people.id)",
    "borrower" => "EXISTS (SELECT 1 FROM loans WHERE loans.person_id = people.id)",
    "employee" => "EXISTS (SELECT 1 FROM payroll_members WHERE payroll_members.person_id = people.id)"
  }.freeze

  self.module_key = "trading"
  self.date_column = "purchases.purchased_at"
  self.date_type = :datetime
  self.default_period = "this_season"
  self.default_sort = :sales_total

  filter :q, :text
  filter :role, :choice, in: ROLES
  filter :activity, :choice, in: ACTIVITIES, default: "with_activity"

  def self.module_keys = %w[trading loans farms]

  detail { |person| loans_credit_account_path(person) }

  column(:person, :text, sort: "people.last_names", &:full_name)
  column(:roles, :text, priority: 3) { |person| PeopleReport.roles_of(person) }
  column(:quintals, :quintals, sort: "sales.net_weight", priority: 2) { |person| person.sales_net_weight.to_d / QUINTAL if person.sales_net_weight }
  column(:sales_total, :money, sort: "sales.total") { |person| person.sales_total }
  column(:earned, :money, sort: "earned.amount", priority: 2) { |person| person.earned_amount }
  column(:repaid, :money, sort: "repaid.amount", priority: 3) { |person| person.repaid_amount }
  column(:owed, :money, sort: "owed.amount") { |person| person.owed_amount if person.owed_amount.to_d.positive? }

  kpi :people, :integer, "COUNT(*) FILTER (WHERE #{ACTIVITY})"
  kpi :sales_total, :money, "COALESCE(SUM(sales.total), 0)"
  kpi :earned, :money, "COALESCE(SUM(earned.amount), 0)"
  kpi :repaid, :money, "COALESCE(SUM(repaid.amount), 0)", good: :up
  kpi :owed, :money, "COALESCE(SUM(owed.amount), 0)", compare: false

  # Names of each person's roles, for the roles column.
  def self.roles_of(person)
    # The selected columns (#preload), not Person#<role>_role, which would load each role.
    ROLES.select { |role| person.has_attribute?(:"#{role}_role") ? person[:"#{role}_role"] : person.public_send(:"#{role}_role") }.map { |role| I18n.t("reports.types.people.roles.#{role}") }.join(" · ")
  end

  def scope = Person.all

  def records(in_period = period)
    apply_filters(Person.joins(join(:sales, sales(in_period))).joins(join(:earned, earned(in_period)))
                        .joins(join(:repaid, repaid(in_period))).joins(OWED))
  end

  def apply_filters(relation)
    relation = relation.merge(Person.search(filter.q)) if filter.q
    relation = relation.where(ACTIVITY) if filter.activity
    relation = role(relation) if filter.role
    relation
  end

  def charts
    relation = records.where(ACTIVITY)
    top = plain(relation).where("#{PAID_TO_THEM} > 0").order(Arel.sql("#{PAID_TO_THEM} DESC")).limit(15)
                         .pluck(Arel.sql(NAME), Arel.sql("COALESCE(sales.total, 0)"), Arel.sql("COALESCE(earned.amount, 0)"))
    debtors = plain(relation).where("owed.amount > 0").order(Arel.sql("owed.amount DESC")).limit(10).pluck(Arel.sql(NAME), Arel.sql("owed.amount"))
    roles = ROLES.map { |key| [ I18n.t("reports.types.people.roles.#{key}"), plain(role_scope(relation, key)).count ] }

    [
      chart(:paid_to_them, :hstacked, labels: top.map(&:first), datasets: [ dataset(:sales_total, top.map { |row| number(row[1]) }, format: :money),
                                                                           dataset(:earned, top.map { |row| number(row[2]) }, format: :money) ],
                                      wide: true),
      chart(:debtors, :hbar, labels: debtors.map(&:first), datasets: [ dataset(:owed, debtors.map { |row| number(row[1]) }, format: :money) ]),
      chart(:roles, :doughnut, labels: roles.map(&:first), datasets: [ dataset(:people, roles.map(&:last), format: :integer) ]),
      locations(:map, relation, place: :person, measure: :paid_to_them, sql: "SUM(#{PAID_TO_THEM})", format: :money)
    ]
  end

  private
    def preload(relation)
      relation.select("people.*", "sales.net_weight AS sales_net_weight", "sales.total AS sales_total", "earned.amount AS earned_amount",
                      "repaid.amount AS repaid_amount", "owed.amount AS owed_amount", *ROLES.map { |key| "#{ROLE_SQL.fetch(key)} AS #{key}_role" })
    end

    def role(relation) = role_scope(relation, filter.role)
    def role_scope(relation, key) = relation.where(ROLE_SQL.fetch(key))

    def join(name, relation) = "LEFT JOIN (#{relation.to_sql}) #{name} ON #{name}.person_id = people.id"

    def sales(in_period)
      within(Purchase.active.joins(:producer), in_period, column: "purchases.purchased_at", type: :datetime)
        .group("producers.person_id").select("producers.person_id", "SUM(purchases.net_weight) AS net_weight", "SUM(purchases.total) AS total")
    end

    def earned(in_period)
      within(PayrollPaymentLine.joins(:payment, :member), in_period, column: "payroll_payments.paid_on")
        .group("payroll_members.person_id").select("payroll_members.person_id", "SUM(payroll_payment_lines.gross_amount) AS amount")
    end

    def repaid(in_period)
      within(LoanPayment.joins(:loan), in_period, column: "loan_payments.paid_on")
        .group("loans.person_id").select("loans.person_id", "SUM(loan_payments.amount) AS amount")
    end
end
