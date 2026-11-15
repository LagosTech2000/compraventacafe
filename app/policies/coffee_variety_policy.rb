# Coffee varieties are a catalog of Fincas (Fernando, 2026-11-15), with the
# permissions of the farms: deactivated, never deleted.
class CoffeeVarietyPolicy < ApplicationPolicy
  self.module_key = "farms"
  self.submodule_key = "farms"

  def destroy? = false
end
