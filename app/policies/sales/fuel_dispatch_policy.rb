# «Combustible» (Fernando, 2026-11-22): what the vehicles took of the
# business's fuel and oil goes with Comercialización → Insumos.
module Sales
  class FuelDispatchPolicy < ApplicationPolicy
    self.module_key = "sales"
    self.submodule_key = "supplies"
  end
end
