# One day of purchases: its totals and the purchases themselves. Voided
# purchases are left out.
class DailyClose < PurchaseSummary
  # Paid first, then pending payment, then not invoiced yet.
  PAYMENT_ORDER = Arel.sql(<<~SQL.squish)
    CASE invoices.payment_status WHEN 'paid' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END
  SQL

  attr_reader :date

  def initialize(date)
    @date = date
    super(Purchase.active.on(date))
  end

  PAYMENT_STATES = %w[paid pending uninvoiced].freeze

  # [[state, purchases], ...] in PAYMENT_STATES order, skipping empty states.
  def groups
    purchases.group_by { |purchase| payment_state(purchase) }
             .sort_by { |state, _| PAYMENT_STATES.index(state) }
  end

  def payment_state(purchase)
    return "uninvoiced" unless purchase.invoice

    purchase.invoice.paid? ? "paid" : "pending"
  end

  # Grouped by payment state, newest first within each group.
  def purchases
    @purchase_list ||= Purchase.active.on(date).left_joins(:invoice).order(PAYMENT_ORDER).merge(Purchase.newest_first)
                               .preload(:invoice, :zone, producer: :person).to_a
  end
end
