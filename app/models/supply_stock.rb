# Inventario de insumos (Fernando, 2026-11-12): of each supply, what came
# in (SupplyEntry) less what the loans took (LoanSupply) since the day the
# inventory started (the loans before it do not count). Nothing is stored:
# a loan or an entry removed changes it at once. A loan never takes more
# than there is (Loan#supplies_in_stock).
class SupplyStock
  # The day it started, when the site settings do not say it.
  STARTED_ON = Date.new(2026, 11, 12)

  Row = Data.define(:supply, :entered, :lent, :invested) do
    def stock = entered - lent
  end

  def self.starts_on = SiteSetting.current.supply_stock_starts_on || STARTED_ON

  # Quantity left of a supply; a loan being edited does not count its own lines.
  def self.available(supply_id, except_loan: nil)
    entered = SupplyEntry.where(supply_id:).sum(:quantity)
    lent = counted_lines.where(supply_id:)
    lent = lent.where.not(loan_id: except_loan) if except_loan
    entered - lent.sum(:quantity)
  end

  # The loans' lines that take from the inventory.
  def self.counted_lines = LoanSupply.joins(:loan).where(loans: { disbursed_on: starts_on.. })

  # Every supply with movements or active, by name.
  def rows
    @rows ||= begin
      entered = SupplyEntry.group(:supply_id).sum(:quantity)
      invested = SupplyEntry.group(:supply_id).sum(:amount)
      lent = self.class.counted_lines.group(:supply_id).sum(:quantity)
      ids = entered.keys | lent.keys
      Supply.where(id: ids).or(Supply.active).ordered.map do |supply|
        Row.new(supply:, entered: entered.fetch(supply.id, 0.to_d), lent: lent.fetch(supply.id, 0.to_d), invested: invested.fetch(supply.id, 0.to_d))
      end
    end
  end

  def for(supply) = rows.find { it.supply == supply }
end
