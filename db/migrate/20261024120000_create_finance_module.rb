# Control financiero (Fernando, 2026-10-23): every money outflow of the
# business, registered, classified and controlled.
#
# - Money accounts (cash boxes and banks) with an opening balance; their
#   balance is the opening plus what came in minus what went out.
# - Expenses and investments of the business, with a two-level category
#   catalog of their own, the account they were paid from and, optionally,
#   the photo or PDF of their receipt.
# - Other income (owner's contributions, bank loans…) and transfers
#   between accounts.
# - A monthly budget per category.
# - Every payment or collection of the other modules says, optionally, its
#   account: the balances count it. Older ones stay without an account.
class CreateFinanceModule < ActiveRecord::Migration[8.1]
  def change
    create_table :money_accounts do |t|
      t.string :name, null: false
      t.string :kind, null: false
      t.string :bank_name
      t.string :account_number
      t.decimal :opening_balance, precision: 14, scale: 2, null: false, default: 0
      t.date :opening_on, null: false
      # The payment methods it is suggested for (cash, transfer, check).
      t.string :default_for, array: true, null: false, default: []
      t.text :observations
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index "lower(name)", unique: true, name: "index_money_accounts_on_lower_name"
    end

    create_table :finance_categories do |t|
      t.string :name, null: false
      t.string :kind, null: false
      t.references :parent, foreign_key: { to_table: :finance_categories }
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index "kind, COALESCE(parent_id, 0), lower(name)", unique: true, name: "index_finance_categories_on_name_in_parent"
    end

    create_table :expenses do |t|
      t.string :kind, null: false, index: true
      t.date :spent_on, null: false, index: true
      t.references :finance_category, null: false, foreign_key: true
      t.references :money_account, null: false, foreign_key: true
      t.string :payee
      t.string :description, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string :payment_method, null: false
      t.string :receipt_number
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    # The photo or PDF of an expense's receipt; its bytes in the database.
    create_table :expense_receipts do |t|
      t.references :expense, null: false, foreign_key: true, index: { unique: true }
      t.binary :data, null: false
      t.string :content_type, null: false
      t.string :filename
      t.integer :byte_size, null: false
      t.timestamps
    end

    create_table :other_incomes do |t|
      t.date :received_on, null: false, index: true
      t.references :money_account, null: false, foreign_key: true
      t.string :concept, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string :payment_method, null: false
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :account_transfers do |t|
      t.date :transferred_on, null: false, index: true
      t.references :from_account, null: false, foreign_key: { to_table: :money_accounts }
      t.references :to_account, null: false, foreign_key: { to_table: :money_accounts }
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :budgets do |t|
      t.references :finance_category, null: false, foreign_key: true, index: false
      t.date :month, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.timestamps
      t.index %i[finance_category_id month], unique: true
    end

    %i[invoice_payments hauler_payments loans loan_payments payroll_payments payroll_expenses sale_payments].each do |table|
      add_reference table, :money_account, foreign_key: true
    end
  end
end
