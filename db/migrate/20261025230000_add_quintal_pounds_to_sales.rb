# A sale's quintal is set per sale (Fernando, 2026-10-25): 120 lb unless the
# user writes another in «Nueva venta». Each sale keeps the one it was
# charged with, so its QQ and total never change afterwards.
class AddQuintalPoundsToSales < ActiveRecord::Migration[8.1]
  def change
    add_column :sales, :quintal_pounds, :decimal, precision: 8, scale: 2, null: false, default: 120
  end
end
