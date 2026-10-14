class PayrollMemberFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  # The list already joins the person. The wage is the member's own or else
  # the role's (PayrollMember#daily_wage).
  sorts person: text("people.first_names", "people.last_names"),
        role: { sql: text("payroll_roles.name"), joins: :role },
        daily_wage: { sql: "COALESCE(payroll_members.daily_wage_override, payroll_roles.daily_wage)", joins: :role },
        status: "NOT payroll_members.active"

  def apply(scope)
    scope = scope.where(person_id: Person.search(q).select(:id)) if q
    scope = scope.where(active: status == "active") if status
    scope.includes(:person, :role).joins(:person).order("people.last_names", "people.first_names")
  end
end
