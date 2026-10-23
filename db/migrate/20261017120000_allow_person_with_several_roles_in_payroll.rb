# The same person can work a daily payroll in several roles (Fernando,
# 2026-10-17: «alguien trabajó como chofer por 3 días y luego como
# jornalero por 2 días»), never twice with the same role nor on the same
# day. Payrolls by task and harvest still take each person once
# (PayrollMember validates it).
class AllowPersonWithSeveralRolesInPayroll < ActiveRecord::Migration[8.1]
  def change
    remove_index :payroll_members, %i[payroll_id person_id], unique: true,
                 name: "index_payroll_members_on_payroll_id_and_person_id"
    add_index :payroll_members, %i[payroll_id person_id payroll_role_id], unique: true, nulls_not_distinct: true,
              name: "index_payroll_members_on_payroll_person_role"
  end
end
