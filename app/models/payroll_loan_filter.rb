# The "Préstamos" tab of a payroll: each member with their account
# (CreditAccount): what they owe today, their open and overdue loans and
# their payer score.
class PayrollLoanFilter < ListFilter
  STANDINGS = %w[owing overdue clear].freeze

  # One member and their account. The rows are computed, not records.
  Row = Data.define(:member, :account) do
    def person = member.person
    def id = member.id
  end

  field :q, :text
  field :standing, :choice, in: STANDINGS

  sorts person: { ruby: ->(row) { [ row.person.first_names, row.person.last_names ] } },
        open_loans: { ruby: ->(row) { row.account.open_loans.size } },
        overdue_loans: { ruby: ->(row) { row.account.overdue_loans.size } },
        total_owed: { ruby: ->(row) { row.account.total_owed } },
        score: { ruby: ->(row) { row.account.score.value } }

  # The payroll's people with their accounts, by name: once each, even when
  # they work it in several roles (their active membership first).
  def self.rows(payroll)
    members = payroll.members.includes(person: { loans: %i[payments supply_items] }).joins(:person)
                     .order("people.first_names", "people.last_names", active: :desc, id: :asc).to_a.uniq(&:person_id)
    members.map { |member| Row.new(member:, account: CreditAccount.new(member.person)) }
  end

  # rows: [Row, ...]
  def apply(rows)
    if q
      matching = Person.search(q).where(id: rows.map { it.person.id }).pluck(:id).to_set
      rows = rows.select { matching.include?(it.person.id) }
    end

    case standing
    when "owing" then rows.select { it.account.open_loans.any? }
    when "overdue" then rows.select { it.account.overdue_loans.any? }
    when "clear" then rows.select { it.account.open_loans.none? }
    else rows
    end
  end
end
