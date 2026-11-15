module Finance
  class BudgetPolicy < ApplicationPolicy
    self.module_key = "finance"
    self.submodule_key = "budget"
  end
end
