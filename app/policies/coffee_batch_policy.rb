# Lots of purchased coffee (Fernando, 2026-11-13) go with Comercialización
# → Salidas: they are made to go on shipments. One on a sold shipment
# changes only by an administrator; one on a shipment is not removed.
class CoffeeBatchPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  def update? = can?(:update) && open?
  def destroy? = can?(:destroy) && !shipped?

  private
    def shipped? = record.is_a?(CoffeeBatch) && record.shipped?
    def open? = !record.is_a?(CoffeeBatch) || !record.shipment&.sold? || user.admin?
end
