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

  def void?
    can?(:destroy) && (!record.is_a?(Sale) || record.voidable?)
  end
end
