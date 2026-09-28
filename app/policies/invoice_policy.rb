class InvoicePolicy < ApplicationPolicy
  self.module_key = "trading"

  # Marking as paid is the only change an invoice accepts.
  def update?
    super && !(record.is_a?(Invoice) && record.paid?)
  end

  def destroy?
    false
  end
end
