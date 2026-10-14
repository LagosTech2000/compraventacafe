# Loans given in the period (by date of disbursement): what was lent, what
# came back, the principal still owed and what is owed today with interest
# (LoanBalance), with the overdue ones and the ones about to fall due.
class LoansReport < Report
  STATUSES = %w[unpaid active overdue paid_off].freeze
  DUES = %w[overdue next_7_days next_30_days this_month].freeze
  PAYMENTS = <<~SQL.squish.freeze
    LEFT JOIN (
      SELECT loan_id, SUM(amount) AS amount, SUM(interest_amount) AS interest, SUM(principal_amount) AS principal,
             MAX(paid_on) AS last_paid_on
      FROM loan_payments GROUP BY loan_id
    ) paid ON paid.loan_id = loans.id
    LEFT JOIN (SELECT loan_id, SUM(total) AS total FROM loan_supplies GROUP BY loan_id) supplied ON supplied.loan_id = loans.id
  SQL
  OWED = "(loans.principal - COALESCE(paid.principal, 0))".freeze
  STATUS = <<~SQL.squish.freeze
    CASE WHEN loans.paid_off_on IS NOT NULL THEN 'paid_off' WHEN loans.due_on < CURRENT_DATE THEN 'overdue' ELSE 'active' END
  SQL
  KIND = <<~SQL.squish.freeze
    CASE WHEN supplied.total IS NULL THEN 'cash' WHEN loans.cash_amount > 0 THEN 'mixed' ELSE 'supplies' END
  SQL
  NAME = "people.first_names || ' ' || people.last_names".freeze

  self.module_key = "loans"
  self.date_column = "loans.disbursed_on"
  self.default_period = "all"
  self.default_sort = :disbursed_on
  self.default_measure = :owed

  filter :q, :text
  filter :status, :choice, in: STATUSES
  filter :kind, :choice, in: Loan::KINDS
  filter :due, :choice, in: DUES

  detail { |loan| loans_loan_path(loan) }

  column(:id, :text, sort: "loans.id", priority: 3) { |loan| "#{Loan.model_name.human} #{loan.id}" }
  column(:person, :text, sort: "people.last_names") { |loan| loan.person.full_name }
  column(:kind, :text, sort: KIND, priority: 3, &:human_kind)
  column(:disbursed_on, :date, sort: "loans.disbursed_on", priority: 2)
  column(:due_on, :date, sort: "loans.due_on", priority: 2)
  column(:principal, :money, sort: "loans.principal")
  column(:monthly_interest_rate, :percent, sort: "loans.monthly_interest_rate", priority: 3)
  column(:paid, :money, sort: "paid.amount", priority: 3) { |loan| loan.paid_amount.to_d }
  column(:interest_paid, :money, sort: "paid.interest", priority: 3) { |loan| loan.interest_paid.to_d }
  column(:owed, :money, sort: OWED, priority: 2) { |loan| loan.principal.to_d - loan.principal_paid.to_d }
  column(:balance, :money) { |loan| loan.balance.total_owed unless loan.paid_off? }
  column(:status, :badge, sort: STATUS) do |loan|
    [ loan.human_status, { "paid_off" => "success", "overdue" => "danger" }.fetch(loan.status, "neutral") ]
  end
  column(:days_late, :integer, sort: "CASE WHEN loans.paid_off_on IS NULL THEN CURRENT_DATE - loans.due_on END", priority: 2) do |loan|
    (Time.zone.today - loan.due_on).to_i if loan.overdue?
  end

  measure :count, :integer, "COUNT(*)"
  measure :principal, :money, "SUM(loans.principal)"
  measure :paid, :money, "COALESCE(SUM(paid.amount), 0)"
  measure :interest_paid, :money, "COALESCE(SUM(paid.interest), 0)"
  measure :owed, :money, "SUM(#{OWED})"
  measure :overdue, :integer, "COUNT(*) FILTER (WHERE loans.paid_off_on IS NULL AND loans.due_on < CURRENT_DATE)"

  group :month, unit: "month"
  group :person, sql: "loans.person_id", label_sql: "MIN(#{NAME})"
  group :status, sql: STATUS, translate: ->(status) { Loan.human_attribute_name("status/#{status}") }
  group :kind, sql: KIND, translate: ->(kind) { Loan.human_attribute_name("kind/#{kind}") }
  group :due_month, sql: "DATE_TRUNC('month', loans.due_on)::date", translate: ->(date) { I18n.l(date.to_date, format: :month_year) }

  kpi :principal, :money, "SUM(loans.principal)"
  kpi :paid, :money, "COALESCE(SUM(paid.amount), 0)", good: :up
  kpi :interest_paid, :money, "COALESCE(SUM(paid.interest), 0)", good: :up
  kpi :owed, :money, "COALESCE(SUM(#{OWED}) FILTER (WHERE loans.paid_off_on IS NULL), 0)", compare: false
  kpi(:balance, :money, compare: false) { |relation, _| owed_today(relation) }
  kpi :overdue_owed, :money, "COALESCE(SUM(#{OWED}) FILTER (WHERE loans.paid_off_on IS NULL AND loans.due_on < CURRENT_DATE), 0)",
      compare: false

  def scope
    Loan.joins(:person).joins(PAYMENTS)
  end

  def apply_filters(relation)
    relation = relation.where(person_id: people_matching(filter.q)) if filter.q
    relation = relation.where("#{STATUS} = ?", filter.status) if filter.status && filter.status != "unpaid"
    relation = relation.where(paid_off_on: nil) if filter.status == "unpaid"
    relation = relation.where("#{KIND} = ?", filter.kind) if filter.kind
    relation = due(relation) if filter.due
    relation
  end

  def charts
    relation = records
    unpaid = relation.where(paid_off_on: nil)
    labels, by_kind = over_time_by(relation, KIND, "SUM(loans.principal)", translate: human(Loan, :kind))
    statuses = breakdown(unpaid, STATUS, "SUM(#{OWED})", translate: human(Loan, :status))
    late = plain(unpaid).where(due_on: ...today).group(:due_on).pluck(:due_on, Arel.sql("SUM(#{OWED})"))
    ages = age_buckets(late.map { |date, amount| [ (today - date).to_i, amount ] }, [ 1, 31, 61, 91 ])
    debtors = breakdown(unpaid, "loans.person_id", "SUM(#{OWED})", label_sql: "MIN(#{NAME})", limit: 10, others: false)
    coming = upcoming(unpaid)

    [
      chart(:lent, :stacked, labels:, datasets: by_kind.map { |set| set.merge(format: :money) }, wide: true),
      chart(:portfolio, :doughnut, labels: statuses.map(&:first), datasets: [ dataset(:owed, statuses.map(&:last), format: :money) ],
                                   tones: { human(Loan, :status).call("active") => "success", human(Loan, :status).call("overdue") => "danger" }),
      chart(:overdue_age, :bar, labels: ages.map(&:first), datasets: [ dataset(:owed, ages.map(&:last), format: :money) ]),
      chart(:debtors, :hbar, labels: debtors.map(&:first), datasets: [ dataset(:owed, debtors.map(&:last), format: :money) ]),
      chart(:upcoming, :bar, labels: coming.map(&:first), datasets: [ dataset(:owed, coming.map(&:last), format: :money) ]),
      locations(:map, relation, place: :person, measure: :lent, sql: "SUM(loans.principal)", format: :money,
                                link: :loans_credit_account_path, link_sql: "people.id")
    ]
  end

  private
    def preload(relation)
      relation.includes(:person, :supply_items)
              .select("loans.*", "paid.amount AS paid_amount", "paid.interest AS interest_paid", "paid.principal AS principal_paid")
    end

    # The balance column needs each loan's payments: load them for the page at once.
    def prepare_rows(loans)
      ActiveRecord::Associations::Preloader.new(records: loans, associations: :payments).call
      loans
    end

    # What the unpaid loans owe today, interest included.
    def owed_today(relation)
      loans = Loan.where(id: relation.where(paid_off_on: nil).select(:id)).includes(:payments).to_a
      loans.sum { |loan| loan.balance(as_of: today).total_owed }
    end

    def due(relation)
      relation = relation.where(paid_off_on: nil)
      case filter.due
      when "overdue" then relation.where(due_on: ...today)
      when "next_7_days" then relation.where(due_on: today..(today + 7))
      when "next_30_days" then relation.where(due_on: today..(today + 30))
      when "this_month" then relation.where(due_on: today.all_month)
      end
    end

    # Principal owed falling due each of the next 8 weeks.
    def upcoming(unpaid)
      weeks = (0...8).map { |week| today.beginning_of_week + week.weeks }
      sums = plain(unpaid).where(due_on: today..(weeks.last + 6)).group(Arel.sql("DATE_TRUNC('week', loans.due_on)::date"))
                          .sum(Arel.sql(OWED))
      weeks.map { |week| [ I18n.t("reports.week_of", date: I18n.l(week, format: :short)), number(sums[week]) ] }
    end
end
