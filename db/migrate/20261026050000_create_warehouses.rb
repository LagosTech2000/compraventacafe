# Warehouses (client, 2026-10-26): the coffee is kept in two, and more can
# be added or taken away. They start as «Bodega 1» and «Bodega 2» and can
# be renamed; «Bodega 1» is the default one. Every purchase comes into a
# warehouse, every shipment and conversion takes coffee out of one, and a
# conversion's result comes into one. Coffee moves between them with
# transfers. What was already recorded goes to «Bodega 1». SQL only, no
# app models.
class CreateWarehouses < ActiveRecord::Migration[8.1]
  def up
    create_table :warehouses do |t|
      t.string :name, null: false
      t.boolean :main, null: false, default: false
      t.text :observations
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :warehouses, "LOWER(name)", unique: true, name: "index_warehouses_on_lower_name"
    add_index :warehouses, :main, unique: true, where: "main", name: "index_warehouses_on_main"

    execute <<~SQL.squish
      INSERT INTO warehouses (name, main, created_at, updated_at)
      VALUES ('Bodega 1', TRUE, NOW(), NOW()), ('Bodega 2', FALSE, NOW(), NOW())
    SQL

    add_reference :purchases, :warehouse, foreign_key: true
    add_reference :shipments, :warehouse, foreign_key: true
    add_reference :coffee_conversions, :warehouse, foreign_key: true
    add_reference :coffee_conversions, :output_warehouse, foreign_key: { to_table: :warehouses }

    main = "(SELECT id FROM warehouses WHERE main)"
    execute "UPDATE purchases SET warehouse_id = #{main}"
    execute "UPDATE shipments SET warehouse_id = #{main}"
    execute "UPDATE coffee_conversions SET warehouse_id = #{main}"
    execute "UPDATE coffee_conversions SET output_warehouse_id = #{main} WHERE finished_at IS NOT NULL"
    change_column_null :purchases, :warehouse_id, false
    change_column_null :shipments, :warehouse_id, false
    change_column_null :coffee_conversions, :warehouse_id, false

    create_table :warehouse_transfers do |t|
      t.integer :number, null: false
      t.datetime :transferred_at, null: false
      t.references :from_warehouse, null: false, foreign_key: { to_table: :warehouses }
      t.references :to_warehouse, null: false, foreign_key: { to_table: :warehouses }
      t.string :coffee_state, null: false
      t.decimal :net_weight, precision: 12, scale: 2, null: false
      t.decimal :gross_weight, precision: 12, scale: 2, null: false
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :warehouse_transfers, :number, unique: true
    add_index :warehouse_transfers, :transferred_at
  end

  def down
    drop_table :warehouse_transfers
    remove_reference :coffee_conversions, :output_warehouse
    remove_reference :coffee_conversions, :warehouse
    remove_reference :shipments, :warehouse
    remove_reference :purchases, :warehouse
    drop_table :warehouses
  end
end
