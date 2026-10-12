class InvoicePolicy < ApplicationPolicy
  self.module_key = "trading"

  # An invoice is never edited: it is paid with payments (InvoicePaymentPolicy).
  def update?
    false
  end

  def destroy?
    false
  end
end
