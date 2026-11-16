# Developments quoted apart and the control center (Fernando, 2026-11-15):
# which are on, their agreed price and the global hourly rate; and the
# first of them, the owners' loans from a bank or another person.
class CreatePaidFeaturesAndOwnerLoans < ActiveRecord::Migration[8.1]
  def up
    create_table :paid_features do |t|
      t.string :key, null: false
      t.boolean :enabled, null: false, default: false
      t.decimal :agreed_price, precision: 14, scale: 2
      t.text :notes
      t.datetime :enabled_at
      t.references :enabled_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :paid_features, :key, unique: true

    create_table :control_settings do |t|
      t.decimal :hourly_rate, precision: 12, scale: 2, null: false, default: 100
      t.timestamps
    end

    create_table :owner_loans do |t|
      t.string :owner_name, null: false
      t.string :lender_name, null: false
      t.date :disbursed_on, null: false
      t.date :due_on
      t.decimal :principal, precision: 14, scale: 2, null: false
      t.decimal :monthly_interest_rate, precision: 6, scale: 3, null: false, default: 0
      t.references :money_account, foreign_key: true
      t.date :paid_off_on
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :owner_loans, :disbursed_on

    create_table :owner_loan_payments do |t|
      t.references :owner_loan, null: false, foreign_key: true
      t.date :paid_on, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.decimal :interest_amount, precision: 14, scale: 2, null: false, default: 0
      t.decimal :principal_amount, precision: 14, scale: 2, null: false, default: 0
      t.string :payment_method, null: false
      t.references :money_account, foreign_key: true
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :owner_loan_payments, :paid_on

    now = connection.quote(Time.current)
    execute "INSERT INTO control_settings (hourly_rate, created_at, updated_at) VALUES (100, #{now}, #{now})"
    execute "INSERT INTO paid_features (key, enabled, agreed_price, enabled_at, created_at, updated_at) VALUES ('fingerprints', TRUE, 2500, #{now}, #{now}, #{now})"
    execute "INSERT INTO paid_features (key, enabled, created_at, updated_at) VALUES ('owner_loans', FALSE, #{now}, #{now})"
  end

  def down
    drop_table :owner_loan_payments
    drop_table :owner_loans
    drop_table :control_settings
    drop_table :paid_features
  end
end
