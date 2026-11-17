# The receipt (photo or PDF) of a shipment's cost (Fernando, 2026-11-16),
# in the same table as the expenses' receipts: each belongs to one or the other.
class AddShipmentCostToExpenseReceipts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :expense_receipts, :expense_id, true
    add_reference :expense_receipts, :shipment_cost, foreign_key: true, index: { unique: true }
    add_check_constraint :expense_receipts, "num_nonnulls(expense_id, shipment_cost_id) = 1", name: "expense_receipts_one_owner"
  end
end
