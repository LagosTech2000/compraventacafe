# Paying an invoice is changing it: it takes editing in the trading module,
# as marking it paid did. Payments are never edited, and only the latest
# one can be removed (the ones after it were counted on it).
class InvoicePaymentPolicy < ApplicationPolicy
  self.module_key = "trading"

  def create?
    can?(:update) && !(record.is_a?(InvoicePayment) && record.invoice.paid?)
  end

  def update?
    false
  end

  def destroy?
    super && record.is_a?(InvoicePayment) && record.latest?
  end
end
