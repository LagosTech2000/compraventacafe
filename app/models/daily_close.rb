# One day of purchases: its totals and the purchases themselves.
class DailyClose < PurchaseSummary
  attr_reader :date

  def initialize(date)
    @date = date
    super(Purchase.on(date))
  end

  def purchases
    @purchase_list ||= Purchase.on(date).includes(:invoice, :zone, producer: :person).newest_first.to_a
  end
end
