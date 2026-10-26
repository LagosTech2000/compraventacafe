# Cash counts (arqueos, Fernando, 2026-10-25): what was really counted in an
# account against what the system said that day, with who counted it.
class CreateCashCounts < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_counts do |t|
      t.references :money_account, null: false, foreign_key: true
      t.date :counted_on, null: false
      t.decimal :counted_amount, precision: 14, scale: 2, null: false
      t.decimal :system_balance, precision: 14, scale: 2, null: false
      t.string :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :cash_counts, %i[money_account_id counted_on]
  end
end
