# What a shipment cost (Fernando, 2026-11-12): the purchase invoices of its
# coffee (each invoice, whole, to one shipment), the costs registered from
# it (as a process's) and expenses of Control financiero assigned to it.
# Only for its cost: the inventory's lots do not change.
class AddCostTracingToShipments < ActiveRecord::Migration[8.1]
  def change
    create_table :shipment_invoices do |t|
      t.references :shipment, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true, index: { unique: true }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :shipment_costs do |t|
      t.references :shipment, null: false, foreign_key: true
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
      t.index :paid_on
    end

    add_reference :expenses, :shipment, foreign_key: true
  end
end
