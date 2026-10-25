# Buyers are Comercialización records. One with shipments or sales is
# deactivated, never deleted.
class BuyerPolicy < ApplicationPolicy
  self.module_key = "sales"

  def destroy?
    super && (!record.is_a?(Buyer) || (record.shipments.none? && record.sales.none?))
  end
end
