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
#
# Of one warehouse (client, 2026-10-26) when given: what came into it and
# left it, transfers included. Of all of them, transfers do not count (the
# coffee stays in the business).
class CoffeeStock
  Row = Data.define(:coffee_state, :purchased, :shipped, :in_transit, :unsold, :gross_purchased, :gross_shipped,
                    :converted_in, :converted_out, :gross_converted_in, :gross_converted_out,
                    :transferred_in, :transferred_out, :gross_transferred_in, :gross_transferred_out) do
    def stock = purchased - shipped + converted_in - converted_out + transferred_in - transferred_out
    def gross_stock = gross_purchased - gross_shipped + gross_converted_in - gross_converted_out + gross_transferred_in - gross_transferred_out
    def quintals = PurchaseCalculation.quintals(stock)
    def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
  end

  attr_reader :date, :warehouse

  def initialize(date = Time.zone.today, warehouse: nil)
    @date = date
    @warehouse = warehouse
  end

  # One row per coffee state, every state (zero ones too).
  def rows
    @rows ||= begin
      purchases = in_warehouse(Purchase.active.where(purchased_at: ..until_moment)).group(:coffee_state)
      purchased = purchases.sum(:net_weight)
      gross_purchased = purchases.sum(:gross_weight)
      shipments = in_warehouse(Shipment.active.where(departed_at: ..until_moment))
      shipped = shipments.group(:coffee_state).sum(:origin_net_weight)
      gross_shipped = shipments.group(:coffee_state).sum(:origin_gross_weight)
      in_transit = shipments.where("shipments.received_on IS NULL OR shipments.received_on > ?", date)
                            .group(:coffee_state).sum(:origin_net_weight)
      unsold = shipments.where(received_on: ..date).where.not(id: SaleLine.active.select(:shipment_id))
                        .group(:coffee_state).sum(:destination_net_weight)
      weighed = conversions.group(:from_state)
      converted_out = weighed.sum(:input_net_weight)
      gross_converted_out = weighed.sum(:input_gross_weight)
      came_out = CoffeeConversion.active.where(finished_at: ..until_moment)
      came_out = came_out.where(output_warehouse_id: warehouse.id) if warehouse
      came_out = came_out.group(:to_state)
      converted_in = came_out.sum(:output_net_weight)
      gross_converted_in = came_out.sum(:output_gross_weight)
      moved_in, moved_out = transfers
      transferred_in = moved_in.sum(:net_weight)
      gross_transferred_in = moved_in.sum(:gross_weight)
      transferred_out = moved_out.sum(:net_weight)
      gross_transferred_out = moved_out.sum(:gross_weight)
      Purchase::COFFEE_STATES.map do |state|
        Row.new(coffee_state: state, purchased: purchased[state] || 0, shipped: shipped[state] || 0,
                in_transit: in_transit[state] || 0, unsold: unsold[state] || 0,
                gross_purchased: gross_purchased[state] || 0, gross_shipped: gross_shipped[state] || 0,
                converted_in: converted_in[state] || 0, converted_out: converted_out[state] || 0,
                gross_converted_in: gross_converted_in[state] || 0, gross_converted_out: gross_converted_out[state] || 0,
                transferred_in: transferred_in[state] || 0, transferred_out: transferred_out[state] || 0,
                gross_transferred_in: gross_transferred_in[state] || 0, gross_transferred_out: gross_transferred_out[state] || 0)
      end
    end
  end

  def row(state) = rows.find { |row| row.coffee_state == state }

  # Net pounds by [warehouse id, coffee state], every warehouse at once (the
  # list of warehouses): in a few queries, not some per warehouse.
  def self.net_by_warehouse(date = Time.zone.today)
    until_moment = date.in_time_zone.end_of_day
    totals = Hash.new(0.to_d)
    add = ->(sums, sign) { sums.each { |key, net| totals[key] += sign * net.to_d } }
    add.call(Purchase.active.where(purchased_at: ..until_moment).group(:warehouse_id, :coffee_state).sum(:net_weight), 1)
    add.call(Shipment.active.where(departed_at: ..until_moment).group(:warehouse_id, :coffee_state).sum(:origin_net_weight), -1)
    add.call(CoffeeConversion.active.where(weighed_at: ..until_moment).group(:warehouse_id, :from_state).sum(:input_net_weight), -1)
    add.call(CoffeeConversion.active.where(finished_at: ..until_moment).group(:output_warehouse_id, :to_state).sum(:output_net_weight), 1)
    moved = WarehouseTransfer.active.where(transferred_at: ..until_moment)
    add.call(moved.group(:to_warehouse_id, :coffee_state).sum(:net_weight), 1)
    add.call(moved.group(:from_warehouse_id, :coffee_state).sum(:net_weight), -1)
    totals
  end

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
    def conversions = in_warehouse(CoffeeConversion.active.where(weighed_at: ..until_moment))
    def in_warehouse(scope) = warehouse ? scope.where(warehouse_id: warehouse.id) : scope

    # [into the warehouse, out of it], grouped by coffee state; none for
    # the whole business.
    def transfers
      return [ WarehouseTransfer.none.group(:coffee_state) ] * 2 unless warehouse

      moved = WarehouseTransfer.active.where(transferred_at: ..until_moment)
      [ moved.where(to_warehouse_id: warehouse.id).group(:coffee_state), moved.where(from_warehouse_id: warehouse.id).group(:coffee_state) ]
    end
end
