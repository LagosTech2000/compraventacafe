# Totals of a set of purchases, computed in SQL: what the Excel's daily close
# block shows, plus how much of the money is in paid invoices, in invoices
# paid in part, in invoices not paid yet, or not invoiced.
class PurchaseSummary
  # Where a purchase's money stands, in the order the screens show it.
  PAYMENT_STATES = %w[paid partial pending uninvoiced].freeze

  # One payment state: how many purchases and how much money.
  PaymentState = Data.define(:state, :count, :amount)

  def initialize(purchases)
    @purchases = purchases.unscope(:order, :includes, :limit, :offset)
  end

  def purchases_count = @purchases.count
  def producers_count = @purchases.distinct.count(:producer_id)
  def gross_weight = total_of(:gross_weight)
  def sacks = total_of(:sacks)
  def net_weight = total_of(:net_weight)
  def quintals = PurchaseCalculation.quintals(net_weight)
  def total = total_of(:total)

  def paid_total = amount_in("paid")
  def partial_total = amount_in("partial")
  def pending_total = amount_in("pending")
  def uninvoiced_total = amount_in("uninvoiced")

  # [PaymentState, ...] in PAYMENT_STATES order, every state (zero ones too).
  def payment_states
    @payment_states ||= begin
      rows = @purchases.left_joins(:invoice).group(Arel.sql("COALESCE(invoices.payment_status, 'uninvoiced')"))
                       .pluck(Arel.sql("COALESCE(invoices.payment_status, 'uninvoiced')"), Arel.sql("COUNT(*)"),
                              Arel.sql("COALESCE(SUM(purchases.total), 0)"))
                       .to_h { |state, count, amount| [ state, [ count, amount ] ] }
      PAYMENT_STATES.map { |state| PaymentState.new(state:, count: rows.dig(state, 0) || 0, amount: rows.dig(state, 1) || 0) }
    end
  end

  # The invoices paid in part that these purchases are in: what they have
  # been paid and what they still owe, for the whole invoice (it can hold
  # purchases outside this set, e.g. from another day).
  def partial_invoice_ids = @purchases.joins(:invoice).where(invoices: { payment_status: "partial" }).distinct.pluck(:invoice_id)

  def partial_paid = @partial_paid ||= InvoicePayment.where(invoice_id: partial_invoice_ids).sum(:amount)

  def partial_balance
    @partial_balance ||= begin
      purchases = Purchase.where(invoice_id: partial_invoice_ids)
      purchases.sum(:total) - LoanPayment.where(purchase_id: purchases.select(:id)).sum(:amount) - partial_paid
    end
  end

  private
    def amount_in(state) = payment_states.find { |row| row.state == state }.amount

    def total_of(column, relation = @purchases)
      relation.sum(Purchase.arel_table[column])
    end
end
