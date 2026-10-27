# Totals of a set of sales (a day, a season, a filtered list), in SQL:
# how many, the buyer's net, QQ (each sale's own pounds), money, and where the money
# stands (collected, collected in part, pending). Voided sales are left out.
class SaleSummary
  STATES = Sale::PAYMENT_STATUSES.reverse.freeze # paid, partial, pending
  State = Data.define(:state, :count, :amount)

  def initialize(sales)
    @sales = sales.unscope(:order, :includes, :limit, :offset).active
  end

  def sales_count = @sales.count
  def buyers_count = @sales.distinct.count(:buyer_id)
  def net_weight = @sales.sum(:net_weight)
  def origin_net_weight = @sales.sum(:origin_net_weight)
  def net_difference = net_weight - origin_net_weight
  # The weight difference in money, each sale at its own price per pound.
  def difference_amount
    @sales.sum(Arel.sql("(sales.net_weight - sales.origin_net_weight) * " \
                        "CASE WHEN sales.price_unit = 'quintal' THEN sales.unit_price / sales.quintal_pounds ELSE sales.unit_price END")).round(2)
  end
  def quintals = @sales.sum("sales.net_weight / sales.quintal_pounds").round(2)
  def total = @sales.sum(:total)
  def collected = SalePayment.where(sale_id: @sales.select(:id)).sum(:amount)
  # What is collected: each sale's buyer settlement when entered, else its total.
  def amount_due = @sales.sum("COALESCE(sales.buyer_total, sales.total)")
  def balance_due = amount_due - collected

  # [State, ...] in STATES order, every state (zero ones too).
  def payment_states
    @payment_states ||= begin
      rows = @sales.group(:payment_status).pluck(:payment_status, Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(sales.total), 0)"))
                   .to_h { |state, count, amount| [ state, [ count, amount ] ] }
      STATES.map { |state| State.new(state:, count: rows.dig(state, 0) || 0, amount: rows.dig(state, 1) || 0) }
    end
  end
end
