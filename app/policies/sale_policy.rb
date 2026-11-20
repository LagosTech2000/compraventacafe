# A sale is not deleted nor edited, by anyone (Fernando, 2026-11-18): it is
# collected in payments (SalePaymentPolicy) or voided, with the delete
# permission, only while it has no payments (remove them first, the latest
# one first).
class SalePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "sales"

  def update?
    false
  end

  def destroy?
    false
  end

  # Entering the buyer's settlement (what it pays per its own liquidation).
  def settle?
    can?(:update) && open?
  end

  def void?
    return can?(:destroy) unless record.is_a?(Sale)

    open? && can?(:destroy) && record.voidable?
  end

  private
    def open? = !record.is_a?(Sale) || !record.voided?
end
