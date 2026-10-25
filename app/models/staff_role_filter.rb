# Roles of the Planilla interna.
class StaffRoleFilter < ListFilter
  STATUSES = %w[active inactive].freeze
  MEMBERS = "(SELECT COUNT(*) FROM staff_members WHERE staff_members.staff_role_id = staff_roles.id AND staff_members.active)".freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("staff_roles.name"), salary: "staff_roles.salary", pay_frequency: "staff_roles.pay_frequency",
        overtime_hour_rate: "staff_roles.overtime_hour_rate", members: MEMBERS

  def apply(scope)
    scope = scope.where("staff_roles.name ILIKE ?", like(q)) if q
    scope = scope.where(active: status == "active") if status
    scope.select("staff_roles.*", "#{MEMBERS} AS members_count").order(:name)
  end
end
