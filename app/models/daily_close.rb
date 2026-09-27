# One day of purchases: its totals and the purchases themselves.
class DailyClose < PurchaseSummary
  # Paid first, then pending payment, then not invoiced yet.
  PAYMENT_ORDER = Arel.sql(<<~SQL.squish)
    CASE invoices.payment_status WHEN 'paid' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END
  SQL

  attr_reader :date

  def initialize(date)
    @date = date
    super(Purchase.on(date))
  end

  # Grouped by payment state, newest first within each group.
  def purchases
    @purchase_list ||= Purchase.on(date).left_joins(:invoice).order(PAYMENT_ORDER).merge(Purchase.newest_first)
                               .preload(:invoice, :zone, producer: :person).to_a
  end
end
