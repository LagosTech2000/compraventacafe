# What a shipment cost (Fernando, 2026-11-12): the coffee of its lots (that
# share of what was paid to the producers for those purchases, Fernando,
# 2026-11-13; before, whole invoices), the haulers' commission of those
# purchases in the same share, the costs registered from it, the expenses
# of Control financiero assigned to it and the carrier's trip price. Only
# sums of what is kept. Without lots the coffee's cost is missing:
# #complete? is false.
class ShipmentCostSummary
  attr_reader :shipment

  def initialize(shipment)
    @shipment = shipment
  end

  def batches = @batches ||= shipment.coffee_batches.includes(:warehouse).to_a
  def complete? = batches.any?

  def totals = @totals ||= shipment.batch_totals || CoffeeBatch::Totals.zero
  def coffee = totals.value
  def hauler_commission = totals.hauler_commission
  def costs = @costs ||= shipment.costs.sum(:amount).to_d
  def expenses = @expenses ||= shipment.expenses.sum(:amount).to_d
  def trip_price = shipment.trip_price.to_d
  def total = coffee + hauler_commission + costs + expenses + trip_price

  # Lempiras per net pound that left (its lots' net; without lots, the local scale).
  def cost_per_pound
    net = shipment.stock_net_weight.to_d
    net.positive? ? (total / net).round(2) : nil
  end
end
