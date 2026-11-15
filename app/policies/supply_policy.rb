# The supplies' catalog: Comercialización → Insumos (Fernando, 2026-11-13;
# before, in Préstamos).
class SupplyPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "supplies"

  def destroy?
    false
  end
end
