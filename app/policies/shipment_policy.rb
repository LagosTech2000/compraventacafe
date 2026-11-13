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

  def destroy?
    false
  end

  def void?
    can?(:destroy) && (!record.is_a?(Shipment) || record.voidable?)
  end

  private
    # Sold, it is not changed, except to complete a local scale left empty
    # (Fernando, 2026-11-12).
    def open?
      !record.is_a?(Shipment) || !(record.voided? || (record.sold? && !record.origin_missing?))
    end
end
