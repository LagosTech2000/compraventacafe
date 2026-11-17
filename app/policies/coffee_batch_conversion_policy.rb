# The processes of a lot (Fernando, 2026-11-16): like its invoices, adding
# or taking one edits the lot (Salidas), only while its shipment is not sold
# (sold, only an administrator).
class CoffeeBatchConversionPolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  def index? = can?(:read)
  def show? = index?
  def create? = can?(:update) && open?
  def destroy? = create?
  def update? = false

  private
    def batch = record.is_a?(CoffeeBatchConversion) ? record.coffee_batch : nil
    def open? = !batch&.processed? && (!batch&.shipment&.sold? || user.admin?)
end
