# Warehouses are Comercialización records. One that nothing uses is
# deleted; a used one is deactivated instead.
class WarehousePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "stock"

  def destroy?
    super && (!record.is_a?(Warehouse) || (!record.main? && record.unused?))
  end
end
