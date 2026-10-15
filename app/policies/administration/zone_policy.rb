module Administration
  # Zones from Administración → Zonas (Fernando, 2026-10-14): with the
  # Administración permissions, not Compra de café's.
  class ZonePolicy < ApplicationPolicy
    self.module_key = "administration"
  end
end
