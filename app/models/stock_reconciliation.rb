# The day's reconciliation (Fernando, 2026-11-18: the client compares the
# day's purchases with what the shipment says): what they do by hand, in
# one screen, of one day and (optional) one warehouse.
#
# - By coffee state: stock when the day began + purchases + processes that
#   gave it − what went to be processed − shipments ± transfers (one
#   warehouse) ± counts' adjustments = stock when it ended, in gross and
#   net pounds, against the day's physical counts.
# - By shipment that left that day: what its lots' purchases say, its local
#   scale and the buyer's, with the differences in pounds, % and lempiras
#   (the shrink at what its lots cost per net pound; the buyer's difference
#   at the sale's price, once sold).
#
# It only reads what the system keeps.
class StockReconciliation
  INS = %w[purchase conversion_in transfer_in].freeze
  OUTS = %w[conversion_out shipment transfer_out].freeze

  StateRow = Data.define(:coffee_state, :opening_gross, :opening_net, :moves, :closing_gross, :closing_net, :counts) do
    # { kind => [gross, net] }, signed: in positive, out negative.
    def move(kind) = moves.fetch(kind, [ 0.to_d, 0.to_d ])
    def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
    def quiet? = moves.empty? && opening_gross.zero? && opening_net.zero? && counts.empty?
  end

  ShipmentRow = Data.define(:shipment, :lots_gross, :lots_net, :lots_value, :origin_gross, :origin_net, :destination_net, :sale) do
    def lots? = lots_gross.present?
    def shrink_gross = (lots_gross - origin_gross if lots? && origin_gross)
    def shrink_net = (lots_net - origin_net if lots? && origin_net)
    def shrink_percent = (shrink_net && lots_net.positive? ? (shrink_net * 100 / lots_net).round(2) : nil)
    # What the lost (or gained) pounds cost, at its lots' value per net pound.
    def shrink_value = (shrink_net && lots_net.positive? ? (shrink_net * lots_value / lots_net).round(2) : nil)
    def buyer_difference = (destination_net - origin_net if destination_net && origin_net)
    def buyer_percent = (buyer_difference && origin_net.positive? ? (buyer_difference * 100 / origin_net).round(2) : nil)
    def buyer_amount = (buyer_difference && sale ? (buyer_difference * sale.price_per_pound).round(2) : nil)
  end

  attr_reader :date, :warehouse

  def initialize(date: Time.zone.today, warehouse: nil)
    @date = date
    @warehouse = warehouse
  end

  def rows
    @rows ||= begin
      opening = CoffeeStock.new(date - 1, warehouse:)
      closing = CoffeeStock.new(date, warehouse:)
      moves = Hash.new { |hash, key| hash[key] = {} }
      StockLedger.new(from: date, to: date, warehouse:).entries.each do |entry|
        gross, net = moves[entry.coffee_state].fetch(entry.kind, [ 0.to_d, 0.to_d ])
        moves[entry.coffee_state][entry.kind] = [ gross + entry.gross, net + entry.net ]
      end
      counts = in_warehouse(StockCount.active.where(counted_at: Purchase.day_range(date))).includes(:warehouse).order(:counted_at, :id).group_by(&:coffee_state)
      Purchase::COFFEE_STATES.map do |state|
        before = opening.row(state)
        after = closing.row(state)
        StateRow.new(coffee_state: state, opening_gross: before.gross_stock.to_d, opening_net: before.stock.to_d, moves: moves[state],
                     closing_gross: after.gross_stock.to_d, closing_net: after.stock.to_d, counts: counts.fetch(state, []))
      end
    end
  end

  def shipments
    @shipments ||= begin
      list = in_warehouse(Shipment.active.where(departed_at: Purchase.day_range(date))).includes(:buyer, active_sale_line: :sale).order(:departed_at, :id).to_a
      batches = CoffeeBatch.where(shipment_id: list.map(&:id)).pluck(:id, :shipment_id)
      totals = CoffeeBatch::Totals.by_batch(batches.map(&:first))
      by_shipment = batches.group_by(&:last).transform_values { |pairs| pairs.map { totals.fetch(it.first, CoffeeBatch::Totals.zero) }.reduce(:+) }
      list.map do |shipment|
        lots = by_shipment[shipment.id]
        ShipmentRow.new(shipment:, lots_gross: lots&.gross, lots_net: lots&.net, lots_value: lots&.value,
                        origin_gross: shipment.origin_gross_weight, origin_net: shipment.origin_net_weight,
                        destination_net: shipment.destination_net_weight, sale: shipment.active_sale_line&.sale)
      end
    end
  end

  private
    def in_warehouse(scope) = warehouse ? scope.where(warehouse_id: warehouse.id) : scope
end
