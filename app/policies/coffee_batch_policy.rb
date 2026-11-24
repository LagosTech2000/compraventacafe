# Lots of purchased coffee (Fernando, 2026-11-13) go with Comercialización
# → Salidas: they are made to go on shipments. One on a sold shipment
# does not change, by anyone (Fernando, 2026-11-18); one on a shipment is
# not removed.
class CoffeeBatchPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  def update? = can?(:update) && open?
  def destroy? = can?(:destroy) && !taken? && !closed?
  # Closing a lot without a shipment (Fernando, 2026-11-22): administrators.
  def close? = admin? && record.is_a?(CoffeeBatch) && !taken? && !closed?
  def reopen? = admin? && record.is_a?(CoffeeBatch) && closed? && (record.stock_count.nil? || record.stock_count.voidable?)

  private
    def taken? = record.is_a?(CoffeeBatch) && record.taken?
    def closed? = record.is_a?(CoffeeBatch) && record.closed?
    def open? = unlocked? || !record.is_a?(CoffeeBatch) || (!record.processed? && !record.shipment&.sold? && !record.closed?)
end
