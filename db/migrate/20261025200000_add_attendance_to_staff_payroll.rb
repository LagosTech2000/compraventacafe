# The Planilla interna pays like the client's Excel (Fernando, 2026-10-25):
# the salary is monthly and each period pays salary ÷ 30 × the days worked,
# marked day by day (full or half), minus the advances. A payment keeps the
# monthly salary and the days it was calculated with; `salary` stays what
# those days earned.
class AddAttendanceToStaffPayroll < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_attendances do |t|
      t.references :staff_member, null: false, foreign_key: true, index: false
      t.date :worked_on, null: false
      t.decimal :day_fraction, precision: 3, scale: 1, null: false
      t.timestamps
    end
    add_index :staff_attendances, %i[staff_member_id worked_on], unique: true

    add_column :staff_payments, :monthly_salary, :decimal, precision: 12, scale: 2
    add_column :staff_payments, :days_worked, :decimal, precision: 5, scale: 1
  end
end
