# What processing the coffee cost (client, 2026-10-26): freight, drying,
# labor, loading and unloading, renting a patio or dryer, fuel and others,
# each paid as an agreed total, per pound or per quintal; per pound or
# quintal it says on what weight (what went in or what came out, gross or
# net) and how many pounds a quintal has (100, 120 or 125). The basis is
# kept with each cost. It goes out of an account of Control financiero and
# adds to the value of the coffee that came out.
class CreateProcessingCosts < ActiveRecord::Migration[8.1]
  def change
    create_table :processing_costs do |t|
      t.references :coffee_conversion, null: false, foreign_key: true
      t.string :concept, null: false
      t.string :description
      t.string :pricing, null: false
      t.string :weight_side
      t.string :weight_kind
      t.integer :quintal_pounds
      t.decimal :base_pounds, precision: 12, scale: 2
      t.decimal :quantity, precision: 14, scale: 4
      t.decimal :unit_price, precision: 12, scale: 4
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.date :paid_on, null: false
      t.string :payment_method, null: false
      t.references :money_account, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :processing_costs, :paid_on
  end
end
