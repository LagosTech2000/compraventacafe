# A shipment in a sale keeps what was charged, and a voided one is kept only
# as a record: neither is edited. Weighing it at destination is editing it.
# It is voided (never deleted) with the delete permission, while in no sale.
class ShipmentPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  # The driver's card beside the shipment form: whoever can fill the form.
  def driver_card? = create? || can?(:update)

  def update?
    super && open?
  end

  def receive?
    update?
  end

  # Empties the local scale: an administrator (like «Sin báscula local»).
  def remove_origin? = update? && user.admin? && (!record.is_a?(Shipment) || !record.origin_missing?)

  # Removes the buyer's scale: while in no sale (the sale charges it).
  def remove_destination? = update? && (!record.is_a?(Shipment) || (record.received? && !record.sold?))

  def destroy?
    false
  end

  def void?
    can?(:destroy) && (!record.is_a?(Shipment) || record.voidable?)
  end

  private
    # Sold, it is not changed, except to complete a local scale left empty
    # (Fernando, 2026-11-12) or by an administrator, whose changes of its
    # scales the sale follows (Fernando, 2026-11-15).
    def open?
      !record.is_a?(Shipment) || !(record.voided? || (record.sold? && !record.origin_missing? && !user.admin?))
    end
end
