# Roles of the Planilla interna: with the permissions of Control financiero.
# One in use is deactivated, not deleted.
class StaffRolePolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "staff"

  def destroy?
    super && record.is_a?(StaffRole) && !record.in_use?
  end
end
