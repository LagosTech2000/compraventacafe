# Carriers and trucks as two catalogs of their own (Fernando, 2026-10-25:
# «agregar la tabla de transportista y camiones», each apart), chosen in a
# shipment; and who drove it: an employee of the Planilla interna or a name
# typed. What shipments had typed (carrier, plate) becomes catalog records.
# SQL only, no app models.
class CreateCarriersAndTrucks < ActiveRecord::Migration[8.1]
  def up
    create_table :carriers do |t|
      t.string :name, null: false
      t.string :rtn
      t.string :phone
      t.string :contact_name
      t.text :observations
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :carriers, "LOWER(name)", unique: true, name: "index_carriers_on_lower_name"

    create_table :trucks do |t|
      t.string :plate, null: false
      t.string :brand_model
      t.string :color
      t.decimal :capacity_quintals, precision: 8, scale: 2
      t.boolean :own, null: false, default: false
      t.text :observations
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :trucks, :plate, unique: true

    add_reference :shipments, :carrier, foreign_key: true
    add_reference :shipments, :truck, foreign_key: true
    add_reference :shipments, :driver, foreign_key: { to_table: :staff_members }
    add_column :shipments, :driver_name, :string

    execute <<~SQL.squish
      INSERT INTO carriers (name, created_at, updated_at)
      SELECT MIN(REGEXP_REPLACE(BTRIM(carrier_name), '\\s+', ' ', 'g')), NOW(), NOW() FROM shipments
      WHERE NULLIF(BTRIM(carrier_name), '') IS NOT NULL GROUP BY LOWER(REGEXP_REPLACE(BTRIM(carrier_name), '\\s+', ' ', 'g'))
    SQL
    execute <<~SQL.squish
      UPDATE shipments SET carrier_id = carriers.id FROM carriers
      WHERE LOWER(REGEXP_REPLACE(BTRIM(shipments.carrier_name), '\\s+', ' ', 'g')) = LOWER(carriers.name)
    SQL
    execute <<~SQL.squish
      INSERT INTO trucks (plate, created_at, updated_at)
      SELECT DISTINCT UPPER(REGEXP_REPLACE(BTRIM(vehicle_plate), '\\s+', ' ', 'g')), NOW(), NOW() FROM shipments
      WHERE NULLIF(BTRIM(vehicle_plate), '') IS NOT NULL
    SQL
    execute <<~SQL.squish
      UPDATE shipments SET truck_id = trucks.id FROM trucks
      WHERE UPPER(REGEXP_REPLACE(BTRIM(shipments.vehicle_plate), '\\s+', ' ', 'g')) = trucks.plate
    SQL

    remove_column :shipments, :carrier_name
    remove_column :shipments, :vehicle_plate
  end

  def down
    add_column :shipments, :carrier_name, :string
    add_column :shipments, :vehicle_plate, :string
    execute "UPDATE shipments SET carrier_name = carriers.name FROM carriers WHERE carriers.id = shipments.carrier_id"
    execute "UPDATE shipments SET vehicle_plate = trucks.plate FROM trucks WHERE trucks.id = shipments.truck_id"
    remove_column :shipments, :driver_name
    remove_reference :shipments, :driver
    remove_reference :shipments, :truck
    remove_reference :shipments, :carrier
    drop_table :trucks
    drop_table :carriers
  end
end
