# Expenses and investments: read, create, edit and delete with the
# permissions of Control financiero.
class ExpensePolicy < ApplicationPolicy
  self.module_key = "finance"
end
