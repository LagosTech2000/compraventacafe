class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.date :purchased_on, null: false
      t.references :producer, null: false, foreign_key: true
      t.references :zone, foreign_key: true
      t.references :invoice, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :coffee_state, null: false
      # Inputs typed by the user.
      t.decimal :gross_weight, precision: 10, scale: 2, null: false
      t.decimal :humidity_percent, precision: 5, scale: 2, null: false
      t.decimal :price_per_pound, precision: 10, scale: 2, null: false
      # Results of PurchaseCalculation, stored so reports never recompute history.
      t.decimal :sacks, precision: 10, scale: 4, null: false
      t.decimal :tare, precision: 10, scale: 2, null: false
      t.decimal :net_weight, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 14, scale: 2, null: false
      t.text :observations

      t.timestamps
    end
    add_index :purchases, :purchased_on
  end
end
