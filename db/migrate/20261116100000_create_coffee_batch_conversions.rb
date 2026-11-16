# A lot can take a share of a finished process (Fernando, 2026-11-16: «el
# café que sale de proceso debería poderse meter a un lote»), like it takes
# a share of a purchase invoice.
class CreateCoffeeBatchConversions < ActiveRecord::Migration[8.1]
  def change
    create_table :coffee_batch_conversions do |t|
      t.references :coffee_batch, null: false, foreign_key: true
      t.references :coffee_conversion, null: false, foreign_key: true
      t.decimal :percent, precision: 9, scale: 4, null: false
      t.decimal :gross_weight, precision: 16, scale: 6, null: false, default: 0
      t.decimal :net_weight, precision: 16, scale: 6, null: false, default: 0
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :coffee_batch_conversions, [ :coffee_batch_id, :coffee_conversion_id ], unique: true, name: "index_batch_conversions_on_batch_and_conversion"
  end
end
