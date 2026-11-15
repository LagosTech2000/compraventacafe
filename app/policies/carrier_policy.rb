# Carriers are Comercialización records. One with shipments is deactivated,
# never deleted.
class CarrierPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "carriers"

  def destroy?
    super && (!record.is_a?(Carrier) || record.shipments.none?)
  end
end
