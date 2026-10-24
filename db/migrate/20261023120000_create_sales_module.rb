# Comercialización (Fernando, 2026-10-23): the coffee in stock is sold to
# exporters, processors (beneficios) and other buyers.
#
# - A truck leaves (shipment) with its buyer, weighed on the local scale
#   (origin) and again on the buyer's (destination); the net weight of each
#   uses the purchase calculation. The stock goes down by the origin net.
# - A sale groups shipments of one buyer already weighed at destination and
#   is charged on the destination net, by the pound or by the quintal of
#   100 lb. Voided (only without payments), its shipments are free again;
#   its lines stay as a record.
# - It is collected in payments, like the invoices.
class CreateSalesModule < ActiveRecord::Migration[8.1]
  def change
    create_table :buyers do |t|
      t.string :name, null: false
      t.string :kind, null: false
      t.string :rtn
      t.string :phone
      t.string :email
      t.string :contact_name
      t.references :department, foreign_key: true
      t.references :municipality, foreign_key: true
      t.text :address_line
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.text :observations
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index "lower(name)", unique: true, name: "index_buyers_on_lower_name"
      t.index :rtn, unique: true, where: "rtn IS NOT NULL"
    end

    create_table :shipments do |t|
      t.integer :number, null: false, index: { unique: true }
      t.references :buyer, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :departed_at, null: false, index: true
      t.integer :season_year, null: false, index: true
      t.string :coffee_state, null: false
      t.string :remission_number
      t.string :carrier_name
      t.string :vehicle_plate
      t.text :observations

      # Local scale.
      t.decimal :origin_gross_weight, precision: 12, scale: 2, null: false
      t.integer :origin_sacks, null: false
      t.decimal :origin_humidity_percent, precision: 5, scale: 2
      t.decimal :origin_damage_percent, precision: 5, scale: 2
      t.decimal :origin_yield_factor, precision: 6, scale: 4
      t.decimal :origin_tare, precision: 12, scale: 2, null: false
      t.decimal :origin_net_weight, precision: 12, scale: 2, null: false

      # The buyer's scale, once it arrived.
      t.date :received_on
      t.string :weight_note_number
      t.decimal :destination_gross_weight, precision: 12, scale: 2
      t.integer :destination_sacks
      t.decimal :destination_humidity_percent, precision: 5, scale: 2
      t.decimal :destination_damage_percent, precision: 5, scale: 2
      t.decimal :destination_yield_factor, precision: 6, scale: 4
      t.decimal :destination_tare, precision: 12, scale: 2
      t.decimal :destination_net_weight, precision: 12, scale: 2

      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    create_table :sales do |t|
      t.integer :number, null: false, index: { unique: true }
      t.references :buyer, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.date :sold_on, null: false, index: true
      t.string :coffee_state, null: false
      t.string :price_unit, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.string :buyer_document_number
      t.text :observations
      # Kept from its shipments when it was made.
      t.decimal :origin_net_weight, precision: 14, scale: 2, null: false
      t.decimal :net_weight, precision: 14, scale: 2, null: false
      t.decimal :total, precision: 14, scale: 2, null: false
      t.string :payment_status, null: false, index: true
      t.string :payment_method
      t.date :paid_on
      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }
      t.string :void_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    # A shipment in a sale. While the sale is not voided the line is active,
    # and a shipment is in one active line at most.
    create_table :sale_lines do |t|
      t.references :sale, null: false, foreign_key: true
      t.references :shipment, null: false, foreign_key: true, index: false
      t.decimal :origin_net_weight, precision: 12, scale: 2, null: false
      t.decimal :net_weight, precision: 12, scale: 2, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index :shipment_id
      t.index :shipment_id, unique: true, where: "active", name: "index_sale_lines_on_active_shipment"
    end

    create_table :sale_payments do |t|
      t.references :sale, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.date :paid_on, null: false, index: true
      t.string :payment_method, null: false
      t.text :observations
      t.timestamps
    end

    # From what difference (%) between the local scale and the buyer's a
    # shipment stands out. Empty: none does (Fernando, 2026-10-23).
    add_column :site_settings, :weight_tolerance_percent, :decimal, precision: 5, scale: 2
  end
end
