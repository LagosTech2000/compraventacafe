# Advances given by buyers or banks (Fernando, 2026-11-16): registered
# without a sale, applied later to one or several sales by a % of the
# advance, or refunded in money; pending until that covers it, then
# cancelled. A bank is a buyer of kind «bank». A collection «con anticipo»
# points at its application. SQL only, no app models.
class CreateBuyerAdvanceApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :buyer_advances, :status, :string, null: false, default: "pending"
    add_column :buyer_advances, :cancelled_on, :date
    add_index :buyer_advances, :status

    create_table :buyer_advance_sales do |t|
      t.references :buyer_advance, null: false, foreign_key: true
      t.references :sale, null: false, foreign_key: true
      t.decimal :percent, precision: 7, scale: 4, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.date :applied_on, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :buyer_advance_sales, %i[buyer_advance_id sale_id], unique: true

    create_table :buyer_advance_refunds do |t|
      t.references :buyer_advance, null: false, foreign_key: true
      t.date :refunded_on, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string :payment_method, null: false
      t.references :money_account, null: false, foreign_key: true
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_reference :sale_payments, :buyer_advance_sale, foreign_key: true, index: { unique: true }
  end
end
