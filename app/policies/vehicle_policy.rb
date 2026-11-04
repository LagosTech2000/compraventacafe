# Vehicles are Comercialización records. One with shipments is deactivated,
# never deleted.
class VehiclePolicy < ApplicationPolicy
  self.module_key = "sales"

  def destroy?
    super && (!record.is_a?(Vehicle) || record.shipments.none?)
  end
end
