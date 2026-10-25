# A shipment in a sale keeps what was charged, and a voided one is kept only
# as a record: neither is edited. Weighing it at destination is editing it.
# It is voided (never deleted) with the delete permission, while in no sale.
class ShipmentPolicy < ApplicationPolicy
  self.module_key = "sales"

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
    def open?
      !record.is_a?(Shipment) || !(record.voided? || record.sold?)
    end
end
