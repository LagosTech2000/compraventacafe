# A receipt is seen by who sees what it belongs to: the expense (or the
# investment), or the shipment of a shipment's cost.
class ExpenseReceiptPolicy < ApplicationPolicy
  self.module_key = "finance"
  self.submodule_key = "expenses"

  private
    def permission_key
      return super unless record.is_a?(ExpenseReceipt)
      return ShipmentCostPolicy.permission_key if record.shipment_cost_id

      record.expense ? ExpensePolicy.permission_key_for(record.expense.kind) : super
    end
end
