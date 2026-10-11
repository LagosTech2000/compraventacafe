# Payments are only added while the loan owes money, never edited, and only
# the latest one can be removed (the others' splits depend on it).
class LoanPaymentPolicy < ApplicationPolicy
  self.module_key = "loans"

  def create?
    super && !(record.is_a?(LoanPayment) && record.loan&.paid_off?)
  end

  def update?
    false
  end

  # A payroll deduction goes away with its payroll payment, not alone.
  def destroy?
    super && record.is_a?(LoanPayment) && record.latest? && !record.from_payroll?
  end
end
