# Where a shipment is in Comercialización's flow (Fernando, 2026-10-23):
# the truck leaves (weighed on the local scale) → weighed at the buyer's →
# sold → collected.
class SalesLifecycle
  include LifecycleSteps

  STAGES = %w[shipped received sold paid].freeze

  def self.for_shipment(shipment)
    return for_sale(shipment.sale) if shipment.sold?

    new(shipment.received? ? "received" : "shipped")
  end

  def self.for_sale(sale)
    new(sale.paid? ? "paid" : "sold")
  end
end
