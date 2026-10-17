# Paying a hauler's commissions takes editing in Compra de café, like paying
# an invoice. Payments are never edited, and only the latest one can be
# removed (the ones after it were counted on it).
class HaulerPaymentPolicy < ApplicationPolicy
  self.module_key = "trading"

  def create?
    can?(:update)
  end

  def update?
    false
  end

  def destroy?
    super && record.is_a?(HaulerPayment) && record.latest?
  end
end
