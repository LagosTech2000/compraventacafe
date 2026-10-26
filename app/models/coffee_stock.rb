# The coffee in stock, by coffee state, in net pounds (Fernando,
# 2026-10-23): what the active purchases weighed net, minus the origin net
# of the shipments not voided. Up to the end of a day (today by default).
#
# Of what left: in transit (not weighed at destination yet) and received
# but not sold. QQ of 125 lb, as the purchases count them. Gross pounds
# too (Fernando, 2026-10-25), the same way: the purchases' gross minus the
# local gross of the shipments.
#
# Conversions (CoffeeConversion) move coffee between states: what goes in
# leaves its state the day it is weighed, and what came out adds to the
# new state the day it is entered. In between it is "in process", apart
# from the states (#in_process_net, #in_process_gross).
class CoffeeStock
  Row = Data.define(:coffee_state, :purchased, :shipped, :in_transit, :unsold, :gross_purchased, :gross_shipped,
                    :converted_in, :converted_out, :gross_converted_in, :gross_converted_out) do
    def stock = purchased - shipped + converted_in - converted_out
    def gross_stock = gross_purchased - gross_shipped + gross_converted_in - gross_converted_out
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
      purchases = Purchase.active.where(purchased_at: ..until_moment).group(:coffee_state)
      purchased = purchases.sum(:net_weight)
      gross_purchased = purchases.sum(:gross_weight)
      shipments = Shipment.active.where(departed_at: ..until_moment)
      shipped = shipments.group(:coffee_state).sum(:origin_net_weight)
      gross_shipped = shipments.group(:coffee_state).sum(:origin_gross_weight)
      in_transit = shipments.where("shipments.received_on IS NULL OR shipments.received_on > ?", date)
                            .group(:coffee_state).sum(:origin_net_weight)
      unsold = shipments.where(received_on: ..date).where.not(id: SaleLine.active.select(:shipment_id))
                        .group(:coffee_state).sum(:destination_net_weight)
      weighed = conversions.group(:from_state)
      converted_out = weighed.sum(:input_net_weight)
      gross_converted_out = weighed.sum(:input_gross_weight)
      came_out = CoffeeConversion.active.where(finished_at: ..until_moment).group(:to_state)
      converted_in = came_out.sum(:output_net_weight)
      gross_converted_in = came_out.sum(:output_gross_weight)
      Purchase::COFFEE_STATES.map do |state|
        Row.new(coffee_state: state, purchased: purchased[state] || 0, shipped: shipped[state] || 0,
                in_transit: in_transit[state] || 0, unsold: unsold[state] || 0,
                gross_purchased: gross_purchased[state] || 0, gross_shipped: gross_shipped[state] || 0,
                converted_in: converted_in[state] || 0, converted_out: converted_out[state] || 0,
                gross_converted_in: gross_converted_in[state] || 0, gross_converted_out: gross_converted_out[state] || 0)
      end
    end
  end

  def row(state) = rows.find { |row| row.coffee_state == state }

  def stock = rows.sum(&:stock)
  def gross_stock = rows.sum(&:gross_stock)

  # What is being converted that day: weighed, its result not entered yet.
  def in_process = @in_process ||= conversions.where("coffee_conversions.finished_at IS NULL OR coffee_conversions.finished_at > ?", until_moment)
  def in_process_net = @in_process_net ||= in_process.sum(:input_net_weight)
  def in_process_gross = @in_process_gross ||= in_process.sum(:input_gross_weight)
  def in_process_quintals = PurchaseCalculation.quintals(in_process_net)
  def quintals = PurchaseCalculation.quintals(stock)
  def in_transit = rows.sum(&:in_transit)
  def unsold = rows.sum(&:unsold)

  private
    def until_moment = date.in_time_zone.end_of_day
    def conversions = CoffeeConversion.active.where(weighed_at: ..until_moment)
end
