# A sale is not deleted: it is collected in payments (SalePaymentPolicy) or
# voided, with the delete permission, while it has no payments. An
# administrator edits it and voids it even collected (Fernando, 2026-11-12).
class SalePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "sales"

  def update?
    admin? && open?
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

    open? && ((can?(:destroy) && record.voidable?) || admin?)
  end

  private
    def open? = !record.is_a?(Sale) || !record.voided?
end
