# The buyer's settlement of a sale (Fernando, 2026-10-25): the total the
# buyer actually pays per their own liquidation, and why it differs from
# the sale's total (quality, freight…). When it is there, it is what is
# collected.
class AddBuyerSettlementToSales < ActiveRecord::Migration[8.1]
  def change
    add_column :sales, :buyer_total, :decimal, precision: 14, scale: 2
    add_column :sales, :buyer_total_reason, :string
  end
end
