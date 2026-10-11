# Farms module: farms, their payrolls (by day, by task or coffee harvest by
# can), the people working each payroll, what they worked, payments per pay
# period (with loan payments taken from the pay) and expenses.
class CreateFarmsAndPayrolls < ActiveRecord::Migration[8.1]
  def change
    create_table :farms do |t|
      t.string :name, null: false
      t.references :department, foreign_key: true
      t.references :municipality, foreign_key: true
      t.text :address_line
      t.text :observations
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :farms, "lower(name)", unique: true, name: "index_farms_on_lower_name"

    create_table :expense_categories do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :expense_categories, "lower(name)", unique: true, name: "index_expense_categories_on_lower_name"

    create_table :payrolls do |t|
      t.references :farm, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :kind, null: false
      t.string :pay_frequency, null: false
      t.date :starts_on, null: false
      t.date :ends_on
      t.decimal :can_price, precision: 10, scale: 2
      t.text :observations
      t.timestamps
    end

    create_table :payroll_roles do |t|
      t.references :payroll, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :daily_wage, precision: 10, scale: 2, null: false
      t.timestamps
    end
    add_index :payroll_roles, "payroll_id, lower(name)", unique: true, name: "index_payroll_roles_on_payroll_and_lower_name"

    create_table :payroll_members do |t|
      t.references :payroll, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :payroll_role, foreign_key: true
      t.decimal :daily_wage_override, precision: 10, scale: 2
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :payroll_members, %i[payroll_id person_id], unique: true

    create_table :payroll_attendances do |t|
      t.references :payroll_member, null: false, foreign_key: true
      t.date :worked_on, null: false
      t.decimal :day_fraction, precision: 3, scale: 2, null: false
      t.timestamps
    end
    add_index :payroll_attendances, %i[payroll_member_id worked_on], unique: true

    create_table :harvest_entries do |t|
      t.references :payroll_member, null: false, foreign_key: true
      t.date :worked_on, null: false
      t.decimal :cans, precision: 8, scale: 2, null: false
      t.timestamps
    end
    add_index :harvest_entries, %i[payroll_member_id worked_on], unique: true

    create_table :payroll_tasks do |t|
      t.references :payroll, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :completed_on
      t.text :observations
      t.timestamps
    end

    create_table :payroll_task_participants do |t|
      t.references :payroll_task, null: false, foreign_key: true
      t.references :payroll_member, null: false, foreign_key: true
      t.timestamps
    end
    add_index :payroll_task_participants, %i[payroll_task_id payroll_member_id], unique: true, name: "index_task_participants_on_task_and_member"

    create_table :payroll_payments do |t|
      t.references :payroll, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.date :period_starts_on, null: false
      t.date :period_ends_on, null: false
      t.date :paid_on, null: false
      t.decimal :gross_total, precision: 14, scale: 2, null: false
      t.decimal :loans_total, precision: 14, scale: 2, null: false
      t.decimal :net_total, precision: 14, scale: 2, null: false
      t.text :observations
      t.timestamps
    end
    add_index :payroll_payments, %i[payroll_id period_starts_on], unique: true

    create_table :payroll_payment_lines do |t|
      t.references :payroll_payment, null: false, foreign_key: true
      t.references :payroll_member, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :rate, precision: 10, scale: 2
      t.decimal :gross_amount, precision: 14, scale: 2, null: false
      t.decimal :loans_amount, precision: 14, scale: 2, null: false, default: 0
      t.decimal :net_amount, precision: 14, scale: 2, null: false
      t.timestamps
    end

    create_table :payroll_expenses do |t|
      t.references :payroll, null: false, foreign_key: true
      t.references :expense_category, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.date :spent_on, null: false
      t.string :description, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.timestamps
    end

    add_reference :loan_payments, :payroll_payment_line, foreign_key: true
  end
end
