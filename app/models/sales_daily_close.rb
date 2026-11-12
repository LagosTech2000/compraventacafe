# One day of Comercialización: the trucks that left, the ones weighed at
# destination, the sales made, the payments collected and the stock at the
# end of the day. Voided records are left out.
class SalesDailyClose
  attr_reader :date

  def initialize(date)
    @date = date
  end

  def departed
    @departed ||= Shipment.active.on(date).includes(:buyer, :active_sale_line, :sale).newest_first.to_a
  end

  def received
    @received ||= Shipment.active.received_on_day(date).includes(:buyer, :active_sale_line, :sale).newest_first.to_a
  end

  def sales
    @sales ||= Sale.active.where(sold_on: date).includes(:buyer, :payments).newest_first.to_a
  end

  def payments
    @payments ||= SalePayment.where(paid_on: date).includes(sale: :buyer).joins(:sale).merge(Sale.active).in_order.to_a
  end

  def summary = @summary ||= SaleSummary.new(Sale.where(sold_on: date))
  def stock = @stock ||= CoffeeStock.new(date)

  # Shipments without the local scale count nothing here (Fernando, 2026-11-12).
  def departed_net = departed.sum { it.origin_net_weight.to_d }
  def departed_sacks = departed.sum { it.origin_sacks.to_i }
  # The difference compares only the ones with both scales.
  def received_origin_net = compared.sum(&:origin_net_weight)
  def received_net = received.sum(&:destination_net_weight)
  def compared = received.reject(&:origin_missing?)
  def received_difference = compared.sum(&:destination_net_weight) - received_origin_net
  def collected = payments.sum(&:amount)

  def received_difference_percent
    received_origin_net.positive? ? (received_difference * 100 / received_origin_net).round(2) : nil
  end
end
