# The coffee in stock, by coffee state, in net pounds (Fernando,
# 2026-10-23): what the active purchases weighed net, minus the origin net
# of the shipments not voided. Up to the end of a day (today by default).
#
# Of what left: in transit (not weighed at destination yet) and received
# but not sold. QQ of 125 lb, as the purchases count them.
class CoffeeStock
  Row = Data.define(:coffee_state, :purchased, :shipped, :in_transit, :unsold) do
    def stock = purchased - shipped
    def quintals = PurchaseCalculation.quintals(stock)
    def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
  end

  attr_reader :date

  def initialize(date = Time.zone.today)
    @date = date
  end

  # One row per coffee state, every state (zero ones too).
  def rows
    @rows ||= begin
      purchased = Purchase.active.where(purchased_at: ..until_moment).group(:coffee_state).sum(:net_weight)
      shipments = Shipment.active.where(departed_at: ..until_moment)
      shipped = shipments.group(:coffee_state).sum(:origin_net_weight)
      in_transit = shipments.where("shipments.received_on IS NULL OR shipments.received_on > ?", date)
                            .group(:coffee_state).sum(:origin_net_weight)
      unsold = shipments.where(received_on: ..date).where.not(id: SaleLine.active.select(:shipment_id))
                        .group(:coffee_state).sum(:destination_net_weight)
      Purchase::COFFEE_STATES.map do |state|
        Row.new(coffee_state: state, purchased: purchased[state] || 0, shipped: shipped[state] || 0,
                in_transit: in_transit[state] || 0, unsold: unsold[state] || 0)
      end
    end
  end

  def row(state) = rows.find { |row| row.coffee_state == state }

  def stock = rows.sum(&:stock)
  def quintals = PurchaseCalculation.quintals(stock)
  def in_transit = rows.sum(&:in_transit)
  def unsold = rows.sum(&:unsold)

  private
    def until_moment = date.in_time_zone.end_of_day
end
