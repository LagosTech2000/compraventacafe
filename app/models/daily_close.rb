# Totals of one day of purchases: what the Excel's daily close block shows,
# plus how much of the day's money is paid, pending or not yet invoiced.
class DailyClose
  attr_reader :date, :purchases

  def initialize(date)
    @date = date
    @purchases = Purchase.on(date).includes(:invoice, :zone, producer: :person).chronological.to_a
  end

  def purchases_count = purchases.size
  def producers_count = purchases.map(&:producer_id).uniq.size
  def gross_weight = sum(:gross_weight)
  def sacks = sum(:sacks)
  def net_weight = sum(:net_weight)
  def total = sum(:total)

  def paid_total = sum(:total) { |p| p.invoice&.paid? }
  def pending_total = sum(:total) { |p| p.invoiced? && !p.invoice.paid? }
  def uninvoiced_total = sum(:total) { |p| !p.invoiced? }

  private
    def sum(attribute, &filter)
      selected = filter ? purchases.select(&filter) : purchases
      selected.sum(BigDecimal("0")) { |purchase| purchase.public_send(attribute) }
    end
end
