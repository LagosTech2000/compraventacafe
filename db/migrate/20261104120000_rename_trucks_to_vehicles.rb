# «Camiones» become «Vehículos» (Fernando, 2026-11-04): a truck, a pick-up…
# each vehicle has its type, from a catalog of its own (vehicle_types, the
# user adds more). It starts with «Camión» and «Pick-up», and every vehicle
# already registered was a truck: it becomes «Camión». The audit trail
# follows the rename. SQL only, no app models.
class RenameTrucksToVehicles < ActiveRecord::Migration[8.1]
  TYPES = [ "Camión", "Pick-up" ].freeze

  def up
    rename_table :trucks, :vehicles
    rename_column :shipments, :truck_id, :vehicle_id

    create_table :vehicle_types do |t|
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :vehicle_types, "LOWER(name)", unique: true, name: "index_vehicle_types_on_lower_name"

    TYPES.each do |name|
      execute "INSERT INTO vehicle_types (name, active, created_at, updated_at) VALUES (#{quote(name)}, TRUE, NOW(), NOW())"
    end

    add_reference :vehicles, :vehicle_type, foreign_key: true
    execute "UPDATE vehicles SET vehicle_type_id = (SELECT id FROM vehicle_types WHERE name = #{quote(TYPES.first)})"
    change_column_null :vehicles, :vehicle_type_id, false

    execute "UPDATE audit_events SET auditable_type = 'Vehicle' WHERE auditable_type = 'Truck'"
    rename_changeset_key "truck_id", "vehicle_id"
  end

  def down
    rename_changeset_key "vehicle_id", "truck_id"
    execute "UPDATE audit_events SET auditable_type = 'Truck' WHERE auditable_type = 'Vehicle'"
    execute "UPDATE audit_events SET changeset = changeset - 'vehicle_type_id' WHERE auditable_type = 'Truck'"

    remove_reference :vehicles, :vehicle_type, foreign_key: true
    drop_table :vehicle_types
    rename_column :shipments, :vehicle_id, :truck_id
    rename_table :vehicles, :trucks
  end

  private
    def quote(value) = connection.quote(value)

    # A shipment's change of vehicle was recorded as "truck_id".
    def rename_changeset_key(from, to)
      execute <<~SQL.squish
        UPDATE audit_events SET changeset = (changeset - #{quote(from)}) || jsonb_build_object(#{quote(to)}, changeset -> #{quote(from)})
        WHERE auditable_type = 'Shipment' AND changeset ? #{quote(from)}
      SQL
    end
end
