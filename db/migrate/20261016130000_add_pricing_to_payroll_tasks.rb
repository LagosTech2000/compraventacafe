# How a task's value is set (Fernando, 2026-10-16): a fixed amount (as
# before), or a quantity × a price: manzanas worked, barrels sprayed
# (fumigation, foliar; with the barrel's liters) or fertilizer applied
# (quintals or pounds). The value is still split in equal parts.
class AddPricingToPayrollTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_tasks, :pricing, :string, null: false, default: "fixed"
    add_column :payroll_tasks, :quantity, :decimal, precision: 12, scale: 2
    add_column :payroll_tasks, :quantity_unit, :string
    add_column :payroll_tasks, :unit_price, :decimal, precision: 12, scale: 2
    add_column :payroll_tasks, :barrel_liters, :decimal, precision: 8, scale: 2
  end
end
