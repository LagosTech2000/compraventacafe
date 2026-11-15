# Categories of Control financiero; deactivated, never deleted.
class FinanceCategoryPolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "categories"

  def destroy?
    false
  end
end
