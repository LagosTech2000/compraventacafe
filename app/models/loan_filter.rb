class LoanFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :status, :choice, in: Loan::STATUSES

  def apply(scope)
    scope = scope.where(disbursed_on: from..) if from
    scope = scope.where(disbursed_on: ..to) if to
    scope = scope.where(person_id: Person.search(q).select(:id)) if q
    scope = scope.with_status(status) if status
    scope.includes(:person, :payments).newest_first
  end
end
