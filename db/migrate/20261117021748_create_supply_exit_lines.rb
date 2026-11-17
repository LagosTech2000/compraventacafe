# An exit of supplies takes several supplies, as an entry (Fernando,
# 2026-11-16): each exit's supply, quantity and price pass to one line.
# SQL only, no app models.
class CreateSupplyExitLines < ActiveRecord::Migration[8.1]
  def up
    create_table :supply_exit_lines do |t|
      t.references :supply_exit, null: false, foreign_key: true
      t.references :supply, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :unit_price, precision: 14, scale: 2
      t.decimal :amount, precision: 14, scale: 2
      t.timestamps
    end
    execute <<~SQL
      INSERT INTO supply_exit_lines (supply_exit_id, supply_id, quantity, unit_price, amount, created_at, updated_at)
      SELECT id, supply_id, quantity, unit_price, amount, created_at, updated_at FROM supply_exits
    SQL
    remove_reference :supply_exits, :supply, index: true
    remove_column :supply_exits, :quantity
    remove_column :supply_exits, :unit_price
  end

  def down
    add_reference :supply_exits, :supply, index: true
    add_column :supply_exits, :quantity, :decimal, precision: 10, scale: 2
    add_column :supply_exits, :unit_price, :decimal, precision: 14, scale: 2
    execute <<~SQL
      UPDATE supply_exits SET supply_id = lines.supply_id, quantity = lines.quantity, unit_price = lines.unit_price
      FROM (SELECT DISTINCT ON (supply_exit_id) * FROM supply_exit_lines ORDER BY supply_exit_id, id) AS lines
      WHERE lines.supply_exit_id = supply_exits.id
    SQL
    drop_table :supply_exit_lines
  end
end
