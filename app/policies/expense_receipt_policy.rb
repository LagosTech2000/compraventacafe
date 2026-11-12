# An expense's receipt is seen by who sees the expense (or the investment).
class ExpenseReceiptPolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "expenses"

  private
    def permission_key
      record.is_a?(ExpenseReceipt) && record.expense ? ExpensePolicy.permission_key_for(record.expense.kind) : super
    end
end
