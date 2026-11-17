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
  # Only the sales with the local scale of every shipment (Fernando, 2026-11-12).
  def net_difference = @sales.where.not(origin_net_weight: nil).sum("sales.net_weight - sales.origin_net_weight")
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

  # QQ sobrantes (Fernando, 2026-11-16): the coffee sold counted in purchase
  # quintals (its local net ÷ 125) against sale quintals (the buyer's net ÷
  # each sale's pounds per quintal). They come from two places:
  # - the quintal's size: 125 lb bought, 100 or 120 sold (with 100, 25 %
  #   more quintals);
  # - the weight: what the buyer weighed more (or less) than the local scale.
  # Money: each part at each sale's own price. Only the sales with the local
  # scale of every shipment count.
  QuintalGain = Data.define(:sales_count, :left_out, :local_net, :buyer_net, :purchase_quintals, :sale_quintals,
                            :size_quintals, :weight_quintals, :size_amount, :weight_amount, :total) do
    def quintals = (sale_quintals - purchase_quintals).round(2)
    def pounds = (buyer_net - local_net).round(2)
    def percent = purchase_quintals.positive? ? (quintals * 100 / purchase_quintals).round(2) : nil
    def amount = (size_amount + weight_amount).round(2)
    # What the coffee sold would bring if sold in purchase quintals at each sale's price per sale quintal.
    def at_purchase_quintals = (total - amount).round(2)
  end

  PRICE_PER_POUND_SQL = "CASE WHEN sales.price_unit = 'quintal' THEN sales.unit_price / sales.quintal_pounds ELSE sales.unit_price END".freeze

  def quintal_gain
    @quintal_gain ||= begin
      weighed = @sales.where.not(origin_net_weight: nil)
      q = PurchaseCalculation::QUINTAL_WEIGHT
      count, local, buyer, sale_qq, size_qq, weight_qq, size_amount, weight_amount, total = weighed.pick(
        Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(sales.origin_net_weight), 0)"), Arel.sql("COALESCE(SUM(sales.net_weight), 0)"),
        Arel.sql("COALESCE(SUM(sales.net_weight / sales.quintal_pounds), 0)"),
        Arel.sql("COALESCE(SUM(sales.origin_net_weight / sales.quintal_pounds - sales.origin_net_weight / #{q}), 0)"),
        Arel.sql("COALESCE(SUM((sales.net_weight - sales.origin_net_weight) / sales.quintal_pounds), 0)"),
        Arel.sql("COALESCE(SUM(sales.origin_net_weight * (1 - sales.quintal_pounds / #{q}.0) * #{PRICE_PER_POUND_SQL}), 0)"),
        Arel.sql("COALESCE(SUM((sales.net_weight - sales.origin_net_weight) * #{PRICE_PER_POUND_SQL}), 0)"),
        Arel.sql("COALESCE(SUM(sales.total), 0)")
      ).map(&:to_d)
      QuintalGain.new(sales_count: count.to_i, left_out: @sales.where(origin_net_weight: nil).count, local_net: local, buyer_net: buyer,
                      purchase_quintals: (local / q).round(2), sale_quintals: sale_qq.round(2), size_quintals: size_qq.round(2),
                      weight_quintals: weight_qq.round(2), size_amount: size_amount.round(2), weight_amount: weight_amount.round(2), total:)
    end
  end

  # [State, ...] in STATES order, every state (zero ones too).
  def payment_states
    @payment_states ||= begin
      rows = @sales.group(:payment_status).pluck(:payment_status, Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(sales.total), 0)"))
                   .to_h { |state, count, amount| [ state, [ count, amount ] ] }
      STATES.map { |state| State.new(state:, count: rows.dig(state, 0) || 0, amount: rows.dig(state, 1) || 0) }
    end
  end
end
