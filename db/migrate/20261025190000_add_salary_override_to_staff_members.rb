# An employee of the Planilla interna can earn their own salary, over their
# role's (Fernando, 2026-10-24: two drivers in the same role with different
# pay), like the own daily wage in Fincas.
class AddSalaryOverrideToStaffMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :staff_members, :salary_override, :decimal, precision: 12, scale: 2
  end
end
