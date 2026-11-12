# Inventario de insumos (Fernando, 2026-11-12): each purchase of a supply is
# an entry (quantity and what it cost) that registers an investment of
# Control financiero by itself; the loans with supplies take from it. Only
# loans from the day the inventory starts count (the ones before do not):
# that day is kept on the site settings.
class CreateSupplyEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :supply_entries do |t|
      t.references :supply, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.date :received_on, null: false
      t.string :payee
      t.string :receipt_number
      t.text :observations
      t.references :expense, null: false, foreign_key: true, index: { unique: true }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
      t.index :received_on
    end

    add_column :site_settings, :supply_stock_starts_on, :date
    reversible do |dir|
      dir.up { execute "UPDATE site_settings SET supply_stock_starts_on = CURRENT_DATE" }
    end
  end
end
