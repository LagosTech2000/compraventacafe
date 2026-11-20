# Physical counts (Fernando, 2026-11-18) go with Inventario: registered with
# the create permission (a large adjustment, only an administrator: the
# model checks it), never edited nor deleted; an administrator voids one.
class StockCountPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "stock"

  def update? = false
  def destroy? = false

  def void?
    admin? && (!record.is_a?(StockCount) || !record.voided?)
  end
end
