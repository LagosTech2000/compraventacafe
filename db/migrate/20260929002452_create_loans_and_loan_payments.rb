class CreateLoansAndLoanPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :loans do |t|
      t.references :person, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.decimal :principal, precision: 14, scale: 2, null: false
      t.decimal :monthly_interest_rate, precision: 5, scale: 2, null: false
      t.date :disbursed_on, null: false, index: true
      t.date :due_on, null: false, index: true
      t.date :paid_off_on
      t.text :observations

      t.timestamps
    end

    create_table :loan_payments do |t|
      t.references :loan, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.date :paid_on, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.decimal :interest_amount, precision: 14, scale: 2, null: false
      t.decimal :principal_amount, precision: 14, scale: 2, null: false
      t.string :payment_method, null: false
      t.text :observations

      t.timestamps
    end
  end
end
