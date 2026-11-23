# A lot closed without a shipment or a process (Fernando, 2026-11-22: lot
# 27's invoices never went on a shipment): it stops being offered; its
# purchases stay active (producers keep their QQ). When its coffee is no
# longer in the warehouse, closing it takes it out with a count adjustment
# (stock_count_id).
class AddClosingToCoffeeBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :coffee_batches, :closed_at, :datetime
    add_reference :coffee_batches, :closed_by, foreign_key: { to_table: :users }
    add_column :coffee_batches, :close_reason, :string
    add_reference :coffee_batches, :stock_count, foreign_key: true
  end
end
