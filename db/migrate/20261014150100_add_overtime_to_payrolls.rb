# Overtime (Fernando, 2026-10-14): each payroll sets what an extra hour is
# worth, and each member paid by day may have, per pay period, extra hours
# (× that value) and extra days (× their daily wage). A payment keeps them
# on its line, so paid periods do not change if the value changes later.
class AddOvertimeToPayrolls < ActiveRecord::Migration[8.1]
  def change
    add_column :payrolls, :overtime_hour_rate, :decimal, precision: 10, scale: 2

    create_table :payroll_overtimes do |t|
      t.references :payroll_member, null: false, foreign_key: true
      t.date :period_starts_on, null: false
      t.decimal :hours, precision: 6, scale: 2, null: false, default: 0
      t.decimal :extra_days, precision: 5, scale: 2, null: false, default: 0
      t.timestamps
    end
    add_index :payroll_overtimes, %i[payroll_member_id period_starts_on], unique: true

    change_table :payroll_payment_lines, bulk: true do |t|
      t.decimal :overtime_hours, precision: 6, scale: 2, null: false, default: 0
      t.decimal :overtime_hour_rate, precision: 10, scale: 2
      t.decimal :extra_days, precision: 5, scale: 2, null: false, default: 0
      t.decimal :overtime_amount, precision: 14, scale: 2, null: false, default: 0
    end
  end
end
