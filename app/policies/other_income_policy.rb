# Other income is registered or removed, never edited (remove and register again).
class OtherIncomePolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "incomes"

  def update?
    false
  end
end
