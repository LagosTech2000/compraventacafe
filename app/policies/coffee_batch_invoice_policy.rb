# The invoices of a lot (Fernando, 2026-11-13): seeing them reads Compra de
# café → Facturas too; adding or taking one edits the lot (Salidas), only
# while its shipment is not sold, by anyone (Fernando, 2026-11-18).
class CoffeeBatchInvoicePolicy < ApplicationPolicy
  self.module_key = "sales"
  self.submodule_key = "shipments"

  def index? = can?(:read) && reads_invoices?
  def show? = index?
  def create? = can?(:update) && reads_invoices? && open?
  def destroy? = create?
  def update? = false

  private
    def reads_invoices? = user.can?("trading.invoices", :read)
    def batch = record.is_a?(CoffeeBatchInvoice) ? record.coffee_batch : nil
    # A lot that went to be processed keeps its invoices (Fernando, 2026-11-16).
    def open? = unlocked? || !batch&.processed? && !batch&.shipment&.sold?
end
