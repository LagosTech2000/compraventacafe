# Trucks are Comercialización records. One with shipments is deactivated,
# never deleted.
class TruckPolicy < ApplicationPolicy
  self.module_key = "sales"

  def destroy?
    super && (!record.is_a?(Truck) || record.shipments.none?)
  end
end
