# The supplies' inventory (Comercialización → Inventario de insumos,
# Fernando, 2026-11-12). An entry is registered or removed, never edited.
class SupplyEntryPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "supplies"

  def update? = false
end
