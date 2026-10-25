# The business's own payroll in Control financiero (Fernando, 2026-10-24:
# «planilla interna del negocio»): roles with their salary per period, pay
# frequency and overtime hour rate; employees (people) in a role; advances
# taken off the payment of their period; goals with a bonus, marked met when
# paying; and the payment of each period, with its receipt.
class CreateStaffPayroll < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_roles do |t|
      t.string :name, null: false
      t.decimal :salary, precision: 12, scale: 2, null: false
      t.string :pay_frequency, null: false
      t.decimal :overtime_hour_rate, precision: 10, scale: 2
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :staff_roles, "LOWER(name)", unique: true, name: "index_staff_roles_on_lower_name"

    create_table :staff_members do |t|
      t.references :person, null: false, foreign_key: true, index: { unique: true }
      t.references :staff_role, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on
      t.boolean :active, null: false, default: true
      t.text :observations
      t.timestamps
    end

    create_table :staff_payments do |t|
      t.references :staff_member, null: false, foreign_key: true
      t.references :staff_role, null: false, foreign_key: true
      t.date :period_starts_on, null: false
      t.date :period_ends_on, null: false
      t.decimal :salary, precision: 12, scale: 2, null: false
      t.decimal :overtime_hours, precision: 8, scale: 2, null: false, default: 0
      t.decimal :overtime_hour_rate, precision: 10, scale: 2
      t.decimal :overtime_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :goals_bonus, precision: 12, scale: 2, null: false, default: 0
      t.decimal :extra_bonus, precision: 12, scale: 2, null: false, default: 0
      t.string :extra_bonus_reason
      t.decimal :gross_total, precision: 12, scale: 2, null: false
      t.decimal :advances_total, precision: 12, scale: 2, null: false, default: 0
      t.decimal :net_total, precision: 12, scale: 2, null: false
      t.date :paid_on, null: false
      t.string :payment_method, null: false
      t.references :money_account, null: false, foreign_key: true
      t.text :observations
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :staff_payments, %i[staff_member_id period_starts_on], unique: true

    create_table :staff_advances do |t|
      t.references :staff_member, null: false, foreign_key: true
      t.date :given_on, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :payment_method, null: false
      t.references :money_account, null: false, foreign_key: true
      t.text :observations
      t.references :staff_payment, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :staff_goals do |t|
      t.references :staff_member, null: false, foreign_key: true
      t.date :period_starts_on, null: false
      t.string :description, null: false
      t.decimal :bonus_amount, precision: 12, scale: 2, null: false
      t.boolean :met
      t.references :staff_payment, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
