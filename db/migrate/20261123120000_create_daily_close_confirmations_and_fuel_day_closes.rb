# «Confirmar cierre» of each daily close (Fernando, 2026-11-23: marks it
# reviewed, no lock) and the day's fuel close, one per day for the whole
# business, wherever it is made.
class CreateDailyCloseConfirmationsAndFuelDayCloses < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_close_confirmations do |t|
      t.string :module_key, null: false
      t.date :day, null: false
      t.references :confirmed_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :daily_close_confirmations, %i[module_key day], unique: true

    create_table :fuel_day_closes do |t|
      t.date :day, null: false, index: { unique: true }
      t.references :closed_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
