# Categories of Control financiero; deactivated, never deleted.
class FinanceCategoryPolicy < ApplicationPolicy
  self.module_key = "finance"

  def destroy?
    false
  end
end
