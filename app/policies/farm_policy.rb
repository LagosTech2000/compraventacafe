# Farms are deactivated, never deleted.
class FarmPolicy < ApplicationPolicy
  self.module_key = "farms"

  def destroy?
    false
  end
end
