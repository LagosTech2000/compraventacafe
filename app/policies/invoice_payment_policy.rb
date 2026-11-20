# Paying an invoice is changing it: it takes editing in the trading module,
# as marking it paid did. Payments are not edited, by anyone, and only the
# latest one can be removed (the ones after it were counted on it; Fernando,
# 2026-11-18: closed records are not edited).
class InvoicePaymentPolicy < ApplicationPolicy
  self.module_key = "trading"
  self.submodule_key = "invoices"

  def create?
    can?(:update) && !(record.is_a?(InvoicePayment) && (record.invoice.paid? || record.invoice.voided?))
  end

  def update?
    false
  end

  def destroy?
    super && record.is_a?(InvoicePayment) && !record.invoice.voided? && record.latest?
  end
end
