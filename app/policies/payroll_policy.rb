# A payroll is deleted only while nothing hangs from it (members, tasks,
# payments, expenses): the database refuses otherwise.
class PayrollPolicy < ApplicationPolicy
  self.module_key = "farms"

  # Recording attendance, cans or tasks.
  def record_work?
    can?(:update)
  end
end
