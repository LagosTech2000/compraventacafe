# Inventario de insumos (Fernando, 2026-11-12; deliveries 2026-11-13): of
# each supply, what came in (SupplyEntryLine) and what the loans took
# (LoanSupply) since the day the inventory started (the loans before it do
# not count):
# - En bodega: what came in − what was delivered (handed out) − what left
#   without a loan (SupplyExit: sold apart or used by the business,
#   Fernando, 2026-11-14).
# - Por entregar: lent and not delivered yet («ya ingresados no quiere decir
#   que ya los entregué»).
# - Disponible: what came in − what was lent − what left without a loan. A loan may lend what there is
#   not: this goes below zero, and the ones still owed say to whom.
# Nothing is stored: a loan, a delivery or an entry removed changes it at once.
class SupplyStock
  # The day it started, when the site settings do not say it.
  STARTED_ON = Date.new(2026, 11, 12)

  Row = Data.define(:supply, :entered, :lent, :delivered, :invested, :exited) do
    def in_warehouse = entered - delivered - exited
    def to_deliver = lent - delivered
    def available = entered - lent - exited
  end

  def self.starts_on = SiteSetting.current.supply_stock_starts_on || STARTED_ON

  def self.entered(supply_id) = SupplyEntryLine.where(supply_id:).sum(:quantity)
  def self.exited(supply_id) = SupplyExit.where(supply_id:).sum(:quantity)

  # What there is of a supply in the warehouse; a line being delivered does
  # not count itself.
  def self.in_warehouse(supply_id, except_line: nil)
    delivered = counted_lines.where(supply_id:).where.not(delivered_on: nil)
    delivered = delivered.where.not(id: except_line) if except_line
    entered(supply_id) - delivered.sum(:quantity) - exited(supply_id)
  end

  # What is left to lend of a supply (it may be below zero); a loan being
  # edited does not count its own lines.
  def self.available(supply_id, except_loan: nil)
    lent = counted_lines.where(supply_id:)
    lent = lent.where.not(loan_id: except_loan) if except_loan
    entered(supply_id) - lent.sum(:quantity) - exited(supply_id)
  end

  # The loans' lines that take from the inventory.
  def self.counted_lines = LoanSupply.joins(:loan).where(loans: { disbursed_on: starts_on.. })

  # Every supply with movements or active, by name.
  def rows
    @rows ||= begin
      entered = SupplyEntryLine.group(:supply_id).sum(:quantity)
      invested = SupplyEntryLine.group(:supply_id).sum(:amount)
      lent = self.class.counted_lines.group(:supply_id).sum(:quantity)
      delivered = self.class.counted_lines.where.not(delivered_on: nil).group(:supply_id).sum(:quantity)
      exited = SupplyExit.group(:supply_id).sum(:quantity)
      ids = entered.keys | lent.keys | exited.keys
      Supply.where(id: ids).or(Supply.active).ordered.map do |supply|
        Row.new(supply:, entered: entered.fetch(supply.id, 0.to_d), lent: lent.fetch(supply.id, 0.to_d),
                delivered: delivered.fetch(supply.id, 0.to_d), invested: invested.fetch(supply.id, 0.to_d),
                exited: exited.fetch(supply.id, 0.to_d))
      end
    end
  end

  def for(supply) = rows.find { it.supply == supply }
end
