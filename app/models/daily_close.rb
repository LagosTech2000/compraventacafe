# One day of purchases: its totals and the purchases themselves. Voided
# purchases are left out. The money is split by where it stands: in paid
# invoices, in invoices paid in part, in invoices not paid yet, not invoiced.
class DailyClose < PurchaseSummary
  # Paid first, then paid in part, then not paid, then not invoiced yet.
  PAYMENT_ORDER = Arel.sql(<<~SQL.squish)
    CASE invoices.payment_status WHEN 'paid' THEN 0 WHEN 'partial' THEN 1 WHEN 'pending' THEN 2 ELSE 3 END
  SQL

  attr_reader :date

  def initialize(date)
    @date = date
    super(Purchase.active.on(date))
  end

  # [[state, purchases], ...] in PAYMENT_STATES order, skipping empty states.
  def groups
    purchases.group_by { |purchase| payment_state(purchase) }
             .sort_by { |state, _| PAYMENT_STATES.index(state) }
  end

  # What each producer sold that day, the one who sold the most first.
  ProducerDay = Data.define(:producer, :purchases) do
    def purchases_count = purchases.size
    def net_weight = purchases.sum(&:net_weight)
    def quintals = PurchaseCalculation.quintals(net_weight)
    def total = purchases.sum(&:total)
    # The purchases' money by payment state, as in the day's totals.
    def total_in(state, close) = purchases.select { |purchase| close.payment_state(purchase) == state }.sum(&:total)
  end

  def by_producer
    @by_producer ||= purchases.group_by(&:producer)
                              .map { |producer, list| ProducerDay.new(producer:, purchases: list.sort_by(&:purchased_at).reverse) }
                              .sort_by { |day| [ -day.net_weight, day.producer.full_name ] }
  end

  def payment_state(purchase)
    purchase.invoice&.payment_status || "uninvoiced"
  end

  # The day's invoices paid in part, with what each has been paid and still
  # owes (for the whole invoice), the lowest number first.
  def partial_invoices
    @partial_invoices ||= purchases.filter_map(&:invoice).select(&:partial?).uniq.sort_by(&:number)
  end

  # Grouped by payment state, newest first within each group.
  def purchases
    @purchase_list ||= Purchase.active.on(date).left_joins(:invoice).order(PAYMENT_ORDER).merge(Purchase.newest_first)
                               .preload(:zone, :farm, :loan_payments, invoice: [ :payments, :producer, { purchases: :loan_payments } ], producer: :person).to_a
  end
end
