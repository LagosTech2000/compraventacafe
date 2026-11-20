# Weighed at destination or sold, a shipment is closed for everyone
# (Fernando, 2026-11-18): only a local scale left empty is completed. A
# voided one is kept only as a record. Weighing it at destination is
# editing it, once; to correct it, its buyer's scale is removed while in no
# sale. It is voided (never deleted) with the delete permission, while in
# no sale.
class ShipmentPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  # The driver's card beside the shipment form: whoever can fill the form.
  def driver_card? = create? || can?(:update)

  def update?
    super && open?
  end

  def receive?
    can?(:update) && (!record.is_a?(Shipment) || !(record.voided? || record.received?))
  end

  # Empties the local scale: an administrator (like «Sin báscula local»),
  # while it is on its way.
  def remove_origin? = update? && user.admin? && (!record.is_a?(Shipment) || !(record.origin_missing? || record.received?))

  # Removes the buyer's scale: while in no sale (the sale charges it). How a
  # weighed shipment is corrected.
  def remove_destination? = can?(:update) && (!record.is_a?(Shipment) || (!record.voided? && record.received? && !record.sold?))

  def destroy?
    false
  end

  def void?
    can?(:destroy) && (!record.is_a?(Shipment) || record.voidable?)
  end

  private
    # Weighed or sold, it is not changed, except to complete a local scale
    # left empty (Fernando, 2026-11-12).
    def open?
      !record.is_a?(Shipment) || !(record.voided? || ((record.sold? || record.received?) && !record.origin_missing?))
    end
end
