# Money accounts are Control financiero records; deactivated, never deleted.
class MoneyAccountPolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "accounts"

  def destroy?
    false
  end
end
