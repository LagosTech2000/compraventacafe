# Costs registered from a shipment (Fernando, 2026-11-12): who creates in
# Salidas registers them; who deletes there removes them. Never edited.
class ShipmentCostPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  def create?
    super && (!record.is_a?(ShipmentCost) || !record.shipment&.voided?)
  end

  def update? = false
end
