# Processing coffee (client, 2026-10-26): where it is processed (the
# ecological machines of others, the business's patio, a dryer that
# charges), how much it should give (an estimate, editable each time:
# 37.95 % of cherry's gross pounds as wet parchment, 50 % of wet parchment's
# when dried) and the humidity of what goes in, to compare later with what
# really came out.
class CreateProcessingSites < ActiveRecord::Migration[8.1]
  def change
    create_table :processing_sites do |t|
      t.string :name, null: false
      t.boolean :own, null: false, default: false
      t.text :observations
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :processing_sites, "LOWER(name)", unique: true, name: "index_processing_sites_on_lower_name"

    add_reference :coffee_conversions, :processing_site, foreign_key: true
    add_column :coffee_conversions, :estimated_yield_percent, :decimal, precision: 5, scale: 2
    add_column :coffee_conversions, :input_humidity_percent, :decimal, precision: 5, scale: 2

    add_column :site_settings, :cherry_yield_percent, :decimal, precision: 5, scale: 2, null: false, default: 37.95
    add_column :site_settings, :drying_yield_percent, :decimal, precision: 5, scale: 2, null: false, default: 50
  end
end
