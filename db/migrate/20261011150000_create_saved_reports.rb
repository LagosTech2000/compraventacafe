# Report filters a user saves to run again (each user their own), and
# indexes on the dates reports filter by.
class CreateSavedReports < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :report_key, null: false
      t.string :name, null: false
      t.jsonb :params, null: false, default: {}
      t.timestamps
    end
    add_index :saved_reports, "user_id, lower(name)", unique: true, name: "index_saved_reports_on_user_and_lower_name"

    add_index :invoices, :issued_on
    add_index :loan_payments, :paid_on
    add_index :payroll_payments, :paid_on
    add_index :payroll_expenses, :spent_on
    add_index :harvest_entries, :worked_on
    add_index :payroll_attendances, :worked_on
  end
end
