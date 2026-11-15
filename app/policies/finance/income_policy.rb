module Finance
  class IncomePolicy < ApplicationPolicy
    self.module_key = "finance"
    self.submodule_key = "incomes"
  end
end
