# An invoice is paid with payments (InvoicePaymentPolicy) and is never
# edited, by anyone (Fernando, 2026-11-18: «que no se pueda editar facturas
# ya canceladas»). To correct it an administrator voids it, with a reason,
# once nothing after it depends on it (Invoice#void!: no payments, no lot
# that left).
class InvoicePolicy < ApplicationPolicy
  self.module_key = "trading"
  self.submodule_key = "invoices"

  def update?
    false
  end

  def void?
    admin? && (!record.is_a?(Invoice) || !record.voided?)
  end

  def destroy?
    false
  end
end
