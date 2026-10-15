module Administration
  # Farms from Administración → Fincas (Fernando, 2026-10-14): with the
  # Administración permissions, not the Fincas module's.
  class FarmPolicy < ApplicationPolicy
    self.module_key = "administration"
  end
end
