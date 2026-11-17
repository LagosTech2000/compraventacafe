# Giving back part of an advance in money: as registering an advance, it
# takes editing Compradores; only the latest is removed.
class BuyerAdvanceRefundPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "buyers"

  def create? = can?(:update)
  def destroy? = super && record.is_a?(BuyerAdvanceRefund) && record.latest?
end
