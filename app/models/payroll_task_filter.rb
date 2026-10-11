class PayrollTaskFilter < ListFilter
  STATUSES = %w[pending completed].freeze

  field :q, :text
  field :status, :choice, in: STATUSES

  def apply(scope)
    scope = scope.where("name ILIKE ?", like(q)) if q
    scope = scope.public_send(status) if status
    scope.includes(participants: { member: :person }).newest_first
  end
end
