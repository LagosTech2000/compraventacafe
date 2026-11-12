# Expenses of Control financiero assigned to a shipment (Fernando,
# 2026-11-12): assigning or letting one go edits the shipment and reads the
# expenses (Control financiero → Gastos). `record` is the shipment.
class ShipmentExpensePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  def index? = can?(:read) && reads_expenses?
  def show? = index?
  def create? = can?(:update) && reads_expenses? && !(record.is_a?(Shipment) && record.voided?)
  def destroy? = create?
  def update? = false

  private
    def reads_expenses? = user.can?(ExpensePolicy.permission_key_for("expense"), :read)
end
