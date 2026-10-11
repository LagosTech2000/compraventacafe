# Paying a period; only the latest payment can be removed (with its loan
# payments, when they are the latest of their loans).
class PayrollPaymentPolicy < ApplicationPolicy
  self.module_key = "farms"

  def update?
    false
  end

  def destroy?
    super && record.is_a?(PayrollPayment) && record.removable?
  end

  # Taking loan payments from the pay registers payments in the loans module.
  def deduct_loans?
    create? && user.can?("loans", :create)
  end
end
