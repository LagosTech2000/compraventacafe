module Finance
  class MovementPolicy < ApplicationPolicy
    self.module_key = "finance"
    self.submodule_key = "movements"
  end
end
