# Converting coffee from one state to the next (Fernando, 2026-10-25): cherry
# to wet parchment, wet to dry parchment. First the gross pounds that go in
# are weighed (they leave their state and are "in process"); then the gross
# pounds that came out are entered (they add to the new state). Each net is
# the gross × the net/gross proportion of that state, kept as it was.
class CreateCoffeeConversions < ActiveRecord::Migration[8.1]
  def change
    create_table :coffee_conversions do |t|
      t.integer :number, null: false, index: { unique: true }
      t.string :from_state, null: false
      t.string :to_state, null: false
      t.datetime :weighed_at, null: false, index: true
      t.decimal :input_gross_weight, precision: 12, scale: 2, null: false
      t.decimal :input_net_weight, precision: 12, scale: 2, null: false
      t.decimal :input_ratio, precision: 8, scale: 6, null: false
      t.string :input_ratio_source, null: false
      t.datetime :finished_at, index: true
      t.decimal :output_gross_weight, precision: 12, scale: 2
      t.decimal :output_net_weight, precision: 12, scale: 2
      t.decimal :output_ratio, precision: 8, scale: 6
      t.string :output_ratio_source
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :finished_by, foreign_key: { to_table: :users }
      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
  end
end
