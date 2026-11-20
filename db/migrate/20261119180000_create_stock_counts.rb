# Physical counts of a warehouse's coffee, each with the adjustment that
# leaves the stock as counted (Fernando, 2026-11-18).
class CreateStockCounts < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_counts do |t|
      t.integer :number, null: false
      t.references :warehouse, null: false, foreign_key: true
      t.string :coffee_state, null: false
      t.datetime :counted_at, null: false
      t.decimal :counted_gross, precision: 12, scale: 2, null: false
      t.integer :counted_sacks
      t.decimal :system_gross, precision: 12, scale: 2, null: false
      t.decimal :system_net, precision: 12, scale: 2, null: false
      t.decimal :gross_weight, precision: 12, scale: 2, null: false
      t.decimal :net_weight, precision: 12, scale: 2, null: false
      t.string :reason
      t.string :reason_detail
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }
      t.string :void_reason
      t.timestamps
    end
    add_index :stock_counts, :number, unique: true
    add_index :stock_counts, %i[warehouse_id coffee_state counted_at]
    add_index :stock_counts, :counted_at

    # Adjustments over this share of the stock are for administrators (2 %
    # to start, pending the client's confirmation).
    add_column :site_settings, :count_admin_percent, :decimal, precision: 5, scale: 2, null: false, default: 2
  end
end
