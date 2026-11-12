# The purchase invoices of a shipment (Fernando, 2026-11-12): linking or
# letting one go edits the shipment and reads the invoices (Compra de
# café → Facturas); seeing them takes reading the invoices too.
class ShipmentInvoicePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  def index? = can?(:read) && reads_invoices?
  def show? = index?
  def create? = can?(:update) && reads_invoices? && open?
  def destroy? = create?
  def update? = false

  private
    def reads_invoices? = user.can?("trading.invoices", :read)
    def open? = !record.is_a?(ShipmentInvoice) || !record.shipment&.voided?
end
