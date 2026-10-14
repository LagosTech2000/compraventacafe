class PersonFilter < ListFilter
  ROLES = %w[clients collaborators producers].freeze

  field :q, :text
  field :role, :choice, in: ROLES
  field :department_id, :id

  sorts name: text("people.first_names", "people.last_names"),
        dni: "people.dni", rtn: "people.rtn", phone: "people.phone",
        roles: { ruby: ->(person) { [ Client, Producer, Collaborator ].select { person.public_send("#{it.model_name.element}?") }.map { it.model_name.human }.join(", ") } }

  def apply(scope)
    scope = scope.public_send(role) if role
    scope = scope.search(q) if q
    scope = scope.where(department_id:) if department_id
    scope.includes(:client, :collaborator, :producer).newest_first
  end
end
