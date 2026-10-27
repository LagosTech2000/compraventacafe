# Coffee moved between warehouses: registered with the create permission,
# voided (never edited nor deleted) with the delete permission.
class WarehouseTransferPolicy < ApplicationPolicy
  self.module_key = "sales"

  def update?
    false
  end

  def destroy?
    false
  end

  def void?
    can?(:destroy) && (!record.is_a?(WarehouseTransfer) || !record.voided?)
  end
end
