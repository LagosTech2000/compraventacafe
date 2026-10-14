# Accounts list: people who have had at least one loan.
class CreditAccountFilter < ListFilter
  STANDINGS = %w[owing overdue].freeze

  field :q, :text
  field :standing, :choice, in: STANDINGS

  # The figures come from each person's account (CreditAccount): sorted in Ruby.
  sorts person: text("people.first_names", "people.last_names"),
        open_loans: { ruby: ->(person) { CreditAccount.new(person).open_loans.size } },
        overdue_loans: { ruby: ->(person) { CreditAccount.new(person).overdue_loans.size } },
        total_owed: { ruby: ->(person) { CreditAccount.new(person).total_owed } },
        score: { ruby: ->(person) { CreditAccount.new(person).score.value } }

  def apply(scope)
    scope = scope.where(id: Loan.select(:person_id))
    scope = scope.where(id: Loan.unpaid.select(:person_id)) if standing == "owing"
    scope = scope.where(id: Loan.overdue.select(:person_id)) if standing == "overdue"
    scope = scope.search(q) if q
    scope.newest_first
  end
end
