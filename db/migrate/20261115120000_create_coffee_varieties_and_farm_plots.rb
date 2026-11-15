# The coffee varieties (a catalog) and the plots of a farm (Fernando,
# 2026-11-15: «lote es una parcela de la finca»; «hay que registrar la
# variedad del café, por finca y parcela»; a purchase may say its plot).
# The catalog starts with the varieties the users were writing in the
# farms' observations.
class CreateCoffeeVarietiesAndFarmPlots < ActiveRecord::Migration[8.1]
  VARIETIES = [ "Lempira", "IHCAFE 90", "Parainema", "Catuaí", "Catimor" ].freeze

  def up
    create_table :coffee_varieties do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :coffee_varieties, "LOWER(name)", unique: true, name: "index_coffee_varieties_on_lower_name"

    add_column :farms, :variety_ids, :bigint, array: true, null: false, default: []

    create_table :farm_plots do |t|
      t.references :farm, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :area_value, precision: 14, scale: 4
      t.string :area_unit
      t.bigint :variety_ids, array: true, null: false, default: []
      t.text :observations
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :farm_plots, "farm_id, LOWER(name)", unique: true, name: "index_farm_plots_on_farm_and_lower_name"

    add_reference :purchases, :farm_plot, foreign_key: true

    now = connection.quote(Time.current)
    VARIETIES.each do |name|
      execute "INSERT INTO coffee_varieties (name, active, created_at, updated_at) VALUES (#{connection.quote(name)}, TRUE, #{now}, #{now})"
    end
  end

  def down
    remove_reference :purchases, :farm_plot, foreign_key: true
    drop_table :farm_plots
    remove_column :farms, :variety_ids
    drop_table :coffee_varieties
  end
end
