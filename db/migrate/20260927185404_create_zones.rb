class CreateZones < ActiveRecord::Migration[8.1]
  def change
    create_table :zones do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :zones, "lower(name)", unique: true, name: "index_zones_on_lower_name"
  end
end
