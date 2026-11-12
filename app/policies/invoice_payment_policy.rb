# Paying an invoice is changing it: it takes editing in the trading module,
# as marking it paid did. Payments are not edited and only the latest one
# can be removed (the ones after it were counted on it), except by an
# administrator: any one, edited or removed (Fernando, 2026-11-12).
class InvoicePaymentPolicy < ApplicationPolicy
  self.module_key = "trading"
  self.submodule_key = "invoices"

  def create?
    can?(:update) && !(record.is_a?(InvoicePayment) && (record.invoice.paid? || record.invoice.voided?))
  end

  def update?
    admin? && record.is_a?(InvoicePayment) && !record.invoice.voided?
  end

  def destroy?
    super && record.is_a?(InvoicePayment) && !record.invoice.voided? && (record.latest? || admin?)
  end
end
