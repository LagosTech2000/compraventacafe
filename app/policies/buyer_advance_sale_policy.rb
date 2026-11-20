# An advance applied to a sale collects it: it takes editing sales (as a
# collection does) and seeing the advances (Compradores). Removing it takes
# the same and, like any collection, only while its collection is the
# sale's latest (Fernando, 2026-11-18: closed records are not edited).
class BuyerAdvanceSalePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "sales"

  def create? = can?(:update) && user.can?("sales.buyers", :read)

  def destroy?
    create? && record.is_a?(BuyerAdvanceSale) && !record.sale.voided? && (record.payment.nil? || record.payment.latest?)
  end
end
