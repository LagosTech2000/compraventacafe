# A task paid in a payroll payment is closed.
class PayrollTaskPolicy < ApplicationPolicy
  self.module_key = "farms"

  def update?
    super && !(record.is_a?(PayrollTask) && record.paid?)
  end

  def destroy?
    super && !(record.is_a?(PayrollTask) && record.paid?)
  end
end
