# Expense categories are a catalog of the farms module: deactivated, never
# deleted.
class ExpenseCategoryPolicy < ApplicationPolicy
  self.module_key = "farms"
  self.submodule_key = "expense_categories"

  def destroy?
    false
  end
end
