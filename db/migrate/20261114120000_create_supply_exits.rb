# Supplies that leave the inventory without a loan (Fernando, 2026-11-14):
# sold apart to a person (the money comes into an account) or used by the
# business (no money).
class CreateSupplyExits < ActiveRecord::Migration[8.1]
  def change
    create_table :supply_exits do |t|
      t.references :supply, null: false, foreign_key: true
      t.string :kind, null: false
      t.date :exited_on, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.references :person, foreign_key: true
      t.decimal :unit_price, precision: 14, scale: 2
      t.decimal :amount, precision: 14, scale: 2
      t.string :payment_method
      t.references :money_account, foreign_key: true
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :supply_exits, :exited_on
  end
end
