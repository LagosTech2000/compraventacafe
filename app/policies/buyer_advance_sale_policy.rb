# An advance applied to a sale collects it: it takes editing sales (as a
# collection does) and seeing the advances (Compradores). Removing it takes
# the same; on a sale already collected in full, only an administrator
# (Fernando, 2026-11-16, as the collections).
class BuyerAdvanceSalePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "sales"

  def create? = can?(:update) && user.can?("sales.buyers", :read)

  def destroy?
    create? && record.is_a?(BuyerAdvanceSale) && !record.sale.voided? && (admin? || !record.sale.paid?)
  end
end
