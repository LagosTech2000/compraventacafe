# Totals of a set of purchases, computed in SQL: what the Excel's daily close
# block shows, plus how much money is paid, pending or not yet invoiced.
class PurchaseSummary
  def initialize(purchases)
    @purchases = purchases.unscope(:order, :includes, :limit, :offset)
  end

  def purchases_count = @purchases.count
  def producers_count = @purchases.distinct.count(:producer_id)
  def gross_weight = total_of(:gross_weight)
  def sacks = total_of(:sacks)
  def net_weight = total_of(:net_weight)
  def total = total_of(:total)

  def paid_total = total_of(:total, @purchases.joins(:invoice).where(invoices: { payment_status: "paid" }))
  def pending_total = total_of(:total, @purchases.joins(:invoice).where(invoices: { payment_status: "pending" }))
  def uninvoiced_total = total_of(:total, @purchases.uninvoiced)

  private
    def total_of(column, relation = @purchases)
      relation.sum(Purchase.arel_table[column])
    end
end
