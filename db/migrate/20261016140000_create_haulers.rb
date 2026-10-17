# Carreros (Fernando, 2026-10-16): people who know producers with coffee to
# sell, fetch it with the business's trucks and earn a commission on each
# purchase they haul, paid by the business apart from the producer.
# Commission = net pounds ÷ 16.5 (a can) × the hauler's can price × their
# percent; each purchase keeps the hauler's percent and can price of its day.
# They are paid on their balance, each payment with its receipt.
class CreateHaulers < ActiveRecord::Migration[8.1]
  def change
    create_table :haulers do |t|
      t.references :person, null: false, foreign_key: true, index: { unique: true }
      t.decimal :commission_percent, precision: 5, scale: 2, null: false
      t.decimal :can_price, precision: 12, scale: 2, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    change_table :purchases, bulk: true do |t|
      t.references :hauler, foreign_key: true
      t.decimal :hauler_commission_percent, precision: 5, scale: 2
      t.decimal :hauler_can_price, precision: 12, scale: 2
      t.decimal :hauler_cans, precision: 12, scale: 2
      t.decimal :hauler_commission, precision: 12, scale: 2
    end

    create_table :hauler_payments do |t|
      t.references :hauler, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 12, scale: 2, null: false
      # What the hauler was still owed after it: kept, so the receipt
      # prints the same later.
      t.decimal :balance_after, precision: 12, scale: 2, null: false
      t.date :paid_on, null: false
      t.string :payment_method, null: false
      t.text :observations
      t.timestamps
    end
  end
end
