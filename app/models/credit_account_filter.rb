# Accounts list: people who have had at least one loan.
class CreditAccountFilter < ListFilter
  STANDINGS = %w[owing overdue].freeze

  field :q, :text
  field :standing, :choice, in: STANDINGS

  def apply(scope)
    scope = scope.where(id: Loan.select(:person_id))
    scope = scope.where(id: Loan.unpaid.select(:person_id)) if standing == "owing"
    scope = scope.where(id: Loan.overdue.select(:person_id)) if standing == "overdue"
    scope = scope.search(q) if q
    scope.newest_first
  end
end
