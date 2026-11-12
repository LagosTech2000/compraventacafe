# What a shipment cost (Fernando, 2026-11-12): the coffee of its purchase
# invoices (what was paid to the producers for those purchases, the
# invoices' total), the haulers' commission of those purchases, the costs
# registered from it, the expenses of Control financiero assigned to it and
# the carrier's trip price. Only sums of what is kept. Without invoices the
# coffee's cost is missing: #complete? is false.
class ShipmentCostSummary
  attr_reader :shipment

  def initialize(shipment)
    @shipment = shipment
  end

  def invoices = @invoices ||= shipment.invoices.includes(:purchases, producer: :person).to_a
  def purchases = invoices.flat_map(&:purchases)
  def complete? = invoices.any?

  def coffee = purchases.sum(0.to_d) { it.total.to_d }
  def hauler_commission = purchases.sum(0.to_d) { it.hauler_commission.to_d }
  def costs = @costs ||= shipment.costs.sum(:amount).to_d
  def expenses = @expenses ||= shipment.expenses.sum(:amount).to_d
  def trip_price = shipment.trip_price.to_d
  def total = coffee + hauler_commission + costs + expenses + trip_price

  # The pounds of the invoices' purchases, to compare with what left.
  def invoiced_net = purchases.sum(0.to_d) { it.net_weight.to_d }

  # Lempiras per net pound that left (the local scale); nil without coffee.
  def cost_per_pound
    net = shipment.origin_net_weight.to_d
    net.positive? ? (total / net).round(2) : nil
  end
end
