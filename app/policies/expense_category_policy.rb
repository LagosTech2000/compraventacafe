# Expense categories are a catalog of the farms module: deactivated, never
# deleted.
class ExpenseCategoryPolicy < ApplicationPolicy
  self.module_key = "farms"

  def destroy?
    false
  end
end
