# The day closed for the whole business (Fernando, 2026-11-18): nothing
# dated that day or before is created, changed or voided. An administrator
# closes; only user 1 reopens, with a reason.
class CreateBusinessDayCloses < ActiveRecord::Migration[8.1]
  def change
    create_table :business_day_closes do |t|
      t.date :closed_on, null: false
      t.string :notes, limit: 500
      t.references :closed_by, null: false, foreign_key: { to_table: :users }
      t.datetime :reopened_at
      t.references :reopened_by, foreign_key: { to_table: :users }
      t.string :reopen_reason, limit: 500
      t.timestamps
    end
    add_index :business_day_closes, :closed_on, unique: true, where: "reopened_at IS NULL", name: "index_business_day_closes_active"
  end
end
