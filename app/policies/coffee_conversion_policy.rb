# Coffee conversions (Comercialización): weighing what goes in is creating,
# entering the result is editing, voiding one in process or taking a
# result off is deleting. Nothing else is edited.
class CoffeeConversionPolicy < ApplicationPolicy
  self.module_key = "sales"

  def update? = false
  def destroy? = false
  def finish? = can?(:update) && (!record.is_a?(CoffeeConversion) || record.in_process?)
  def void? = can?(:destroy) && (!record.is_a?(CoffeeConversion) || record.in_process?)
  def reopen? = can?(:destroy) && (!record.is_a?(CoffeeConversion) || record.finished?)
end
