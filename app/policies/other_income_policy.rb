# Other income is registered or removed, never edited (remove and register again).
class OtherIncomePolicy < ApplicationPolicy
  self.module_key = "finance"

  def update?
    false
  end
end
