# Employees of the Planilla interna, alphabetical.
class StaffMemberFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :role, :id
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: { sql: text("people.first_names", "people.last_names"), joins: :person },
        role: { sql: text("staff_roles.name"), joins: :role },
        pay_frequency: { sql: "staff_roles.pay_frequency", joins: :role },
        salary: { sql: "COALESCE(staff_members.salary_override, staff_roles.salary)", joins: :role },
        starts_on: "staff_members.starts_on",
        next_period: { ruby: ->(member) { member.period_to_pay&.starts_on } }

  def apply(scope)
    scope = scope.where(person_id: Person.search(q).select(:id)) if q
    scope = scope.where(staff_role_id: role) if role
    scope = scope.where(active: status == "active") if status
    scope.includes({ person: :photo_info }, :role, :payments, :advances).newest_first
  end
end
