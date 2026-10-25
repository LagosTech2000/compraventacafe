# Money accounts are Control financiero records; deactivated, never deleted.
class MoneyAccountPolicy < ApplicationPolicy
  self.module_key = "finance"

  def destroy?
    false
  end
end
