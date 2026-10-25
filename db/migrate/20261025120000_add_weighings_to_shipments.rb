# A truck can be weighed on the local scale in one figure or by weighings,
# like a purchase (Fernando, 2026-10-25): each weighing with its weight and
# the sacks counted; the gross weight and the sacks are their sums.
class AddWeighingsToShipments < ActiveRecord::Migration[8.1]
  def change
    add_column :shipments, :origin_weight_mode, :string, null: false, default: "single"

    create_table :shipment_weighings do |t|
      t.references :shipment, null: false, foreign_key: true
      t.decimal :gross_weight, precision: 12, scale: 2, null: false
      t.integer :sacks, null: false
      t.timestamps
    end
  end
end
