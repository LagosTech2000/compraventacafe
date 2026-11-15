# Supplies sold apart or used by the business (Comercialización → Insumos →
# Salidas, Fernando, 2026-11-14). Registered or removed, never edited.
class SupplyExitPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "supplies"

  def update? = false
end
