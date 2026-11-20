# Lots of purchased coffee (Fernando, 2026-11-13) go with Comercialización
# → Salidas: they are made to go on shipments. One on a sold shipment
# does not change, by anyone (Fernando, 2026-11-18); one on a shipment is
# not removed.
class CoffeeBatchPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  def update? = can?(:update) && open?
  def destroy? = can?(:destroy) && !taken?

  private
    def taken? = record.is_a?(CoffeeBatch) && record.taken?
    def open? = !record.is_a?(CoffeeBatch) || (!record.processed? && !record.shipment&.sold?)
end
