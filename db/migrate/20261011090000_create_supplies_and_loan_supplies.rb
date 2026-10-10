# Supplies (fertilizer, fungicide...) lent as part of a loan. A loan's
# principal becomes its cash plus the value of its supplies. Loan payments
# can also come from a coffee purchase ("pago con café").
class CreateSuppliesAndLoanSupplies < ActiveRecord::Migration[8.1]
  def change
    create_table :supplies do |t|
      t.string :name, null: false
      t.string :unit, null: false
      t.decimal :default_price, precision: 12, scale: 2, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :supplies, "lower(name)", unique: true, name: "index_supplies_on_lower_name"

    create_table :loan_supplies do |t|
      t.references :loan, null: false, foreign_key: true
      t.references :supply, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 14, scale: 2, null: false
      t.timestamps
    end

    add_column :loans, :cash_amount, :decimal, precision: 14, scale: 2, null: false, default: 0
    reversible do |direction|
      direction.up { execute "UPDATE loans SET cash_amount = principal" }
    end

    add_reference :loan_payments, :purchase, foreign_key: true
  end
end
