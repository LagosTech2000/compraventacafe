# Employees of the Planilla interna: with the permissions of Control
# financiero. One with payments or advances is deactivated, not deleted.
class StaffMemberPolicy < ApplicationPolicy
  self.module_key = "finance"

  def destroy?
    super && record.is_a?(StaffMember) && record.payments.none? && record.advances.none? && record.goals.none?
  end
end
