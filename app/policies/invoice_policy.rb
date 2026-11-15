class InvoicePolicy < ApplicationPolicy
  self.module_key = "trading"
  self.submodule_key = "invoices"

  # An invoice is paid with payments (InvoicePaymentPolicy). Only an
  # administrator edits or voids it, even paid (Fernando, 2026-11-12).
  def update?
    admin? && open?
  end

  def void? = update?

  def destroy?
    false
  end

  private
    def open? = !record.is_a?(Invoice) || !record.voided?
end
