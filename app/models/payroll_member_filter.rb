class PayrollMemberFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  def apply(scope)
    scope = scope.where(person_id: Person.search(q).select(:id)) if q
    scope = scope.where(active: status == "active") if status
    scope.includes(:person, :role).joins(:person).order("people.last_names", "people.first_names")
  end
end
