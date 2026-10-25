# Advances a buyer gives the business (Fernando, 2026-10-25: «los
# compradores nos facilitan adelantos los cuales después pagamos con café,
# sin intereses, y se pueden restar de una venta»). The money comes into an
# account when received; what is taken off a sale is a collection «con
# anticipo» (sale_payments.payment_method = "advance") that moves no money.
class CreateBuyerAdvances < ActiveRecord::Migration[8.1]
  def change
    create_table :buyer_advances do |t|
      t.references :buyer, null: false, foreign_key: true
      t.date :received_on, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :payment_method, null: false
      t.references :money_account, null: false, foreign_key: true
      t.string :document_number
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
