# Lots taken by a shipment after it was registered (Fernando, 2026-11-13):
# editing the shipment, while it is neither voided nor sold (by anyone,
# Fernando, 2026-11-18). The record is the shipment.
class ShipmentBatchPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  def create? = can?(:update) && open?
  def new? = create?
  def destroy? = create?

  private
    def open? = !record.is_a?(Shipment) || !(record.voided? || record.sold?)
end
