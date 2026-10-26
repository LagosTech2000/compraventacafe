# A sale is never edited nor deleted: it is collected in payments
# (SalePaymentPolicy) or voided, with the delete permission, while it has
# no payments.
class SalePolicy < ApplicationPolicy
  self.module_key = "sales"

  def update?
    false
  end

  def destroy?
    false
  end

  # Entering the buyer's settlement (what it pays per its own liquidation).
  def settle?
    can?(:update) && (!record.is_a?(Sale) || !record.voided?)
  end

  def void?
    can?(:destroy) && (!record.is_a?(Sale) || record.voidable?)
  end
end
