class PersonFilter < ListFilter
  ROLES = %w[clients collaborators producers].freeze

  field :q, :text
  field :role, :choice, in: ROLES
  field :department_id, :id

  def apply(scope)
    scope = scope.public_send(role) if role
    scope = scope.search(q) if q
    scope = scope.where(department_id:) if department_id
    scope.includes(:client, :collaborator, :producer).newest_first
  end
end
