# Supplies are a catalog of the loans module, like zones in trading.
class SupplyPolicy < ApplicationPolicy
  self.module_key = "loans"
  self.submodule_key = "supplies"

  def destroy?
    false
  end
end
