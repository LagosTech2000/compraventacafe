# Whether a loan's supply was handed out (Fernando, 2026-11-13): the list
# of what is still owed goes with Comercialización → Insumos; marking it
# delivered, or not, is for administrators only.
class SupplyDeliveryPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "supplies"

  def update? = admin?
  def destroy? = admin?
end
