# Paying a period of the Planilla interna takes creating in Control
# financiero. Payments are never edited; only the latest one of an employee
# is removed.
class StaffPaymentPolicy < ApplicationPolicy
  self.module_key = "finance"

  def update?
    false
  end

  def destroy?
    super && record.is_a?(StaffPayment) && record.latest?
  end
end
