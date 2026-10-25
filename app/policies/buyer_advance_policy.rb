# Advances of a buyer: registering one takes editing in Comercialización,
# like a collection. Never edited; removed only while not taken off a sale.
class BuyerAdvancePolicy < ApplicationPolicy
  self.module_key = "sales"

  def create? = can?(:update)
  def update? = false

  def destroy?
    super && (!record.is_a?(BuyerAdvance) || record.removable?)
  end
end
