# A purchase's gross weight can be entered in one figure ("single") or as
# several weighings ("weighings"), each with its weight and the sacks counted
# on the scale. With weighings, the gross weight and the sacks are their sums
# and the tare is 1 lb per counted sack.
class CreatePurchaseWeighings < ActiveRecord::Migration[8.1]
  def change
    add_column :purchases, :weight_mode, :string, null: false, default: "single"

    create_table :purchase_weighings do |t|
      t.references :purchase, null: false, foreign_key: true
      t.decimal :gross_weight, precision: 10, scale: 2, null: false
      t.integer :sacks, null: false
      t.timestamps
    end
  end
end
