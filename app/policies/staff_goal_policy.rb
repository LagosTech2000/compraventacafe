# Goals of the Planilla interna: set or removed (only before their period is
# paid), never edited.
class StaffGoalPolicy < ApplicationPolicy
  self.module_key = "finance"

  def update?
    false
  end

  def destroy?
    super && record.is_a?(StaffGoal) && !record.paid?
  end
end
