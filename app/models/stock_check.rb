# The net pounds and sacks of the stock, checked (Fernando, 2026-11-16:
# «mostrar netas esperadas, calculando el 49 % de esas libras brutas, y las
# netas que se calcularon por cada compra en separado, al igual con los
# sacos»).
#
# - Expected net: the gross in stock × the usual factor of its coffee state
#   (1 − the purchase's starting humidity, or the cherry's starting yield).
# - Calculated net: what the stock says (CoffeeStock), purchase by purchase.
# - Expected sacks: gross ÷ 165, whole sacks (PurchaseCalculation.whole_sacks).
# - Calculated sacks: what is left of each purchase's sacks (CoffeeLots).
#
# Why they differ (#explanation, administrators): every movement's net − its
# gross × the factor. Purchases add theirs (tare, damage, other humidity or
# yield), what left takes its own off (a shipment with lots takes the net
# of its lots' purchases; without lots, its local scale's net), and so do
# processes and transfers. The sum is the difference, to the cent.
class StockCheck
  Row = Data.define(:coffee_state, :gross, :net, :lots_sacks) do
    def factor = StockCheck.factor(coffee_state)
    def expected_net = (gross * factor).round(2)
    def difference = (net - expected_net).round(2)
    def expected_sacks = PurchaseCalculation.whole_sacks(gross)
    def sacks = lots_sacks.round(2)
    def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
    def factor_percent = (factor * 100).round(2)
  end

  # One movement's part in the difference: net − gross × factor (signed:
  # what left counts against).
  Part = Data.define(:key, :gross, :net, :effect, :items)
  Item = Data.define(:label, :at, :gross, :net, :expected, :effect, :with_lots, :record)

  def self.factor(coffee_state)
    return PurchaseDefaults::CHERRY_YIELD if coffee_state == "cherry"

    (100 - PurchaseDefaults::HUMIDITY_PERCENT.fetch(coffee_state)).to_d / 100
  end

  attr_reader :stock, :warehouse

  def initialize(stock: nil, warehouse: nil, lots: nil)
    @warehouse = warehouse
    @stock = stock || CoffeeStock.new(warehouse:)
    @lots = lots
  end

  def rows
    @rows ||= begin
      sacks = lots.group_by(&:coffee_state).transform_values { it.sum(0.to_d, &:sacks) }
      stock.rows.map { Row.new(coffee_state: it.coffee_state, gross: it.gross_stock.to_d, net: it.stock.to_d, lots_sacks: sacks.fetch(it.coffee_state, 0.to_d)) }
    end
  end

  def row(state) = rows.find { it.coffee_state == state }

  # Every state together: the expected net is the sum of each state's.
  def total
    Data.define(:gross, :net, :expected_net, :difference, :expected_sacks, :sacks).new(
      gross: rows.sum(&:gross), net: rows.sum(&:net), expected_net: rows.sum(&:expected_net), difference: rows.sum(&:difference),
      expected_sacks: PurchaseCalculation.whole_sacks(rows.sum(&:gross)), sacks: rows.sum(&:sacks)
    )
  end

  # Why the calculated net is not the expected one, for one coffee state:
  # the parts, which add up to the difference.
  def explanation(state)
    factor = self.class.factor(state)
    parts = [ purchases_part(state, factor), shipments_part(state, factor), processes_part(state, factor, :in),
              processes_part(state, factor, :out), transfers_part(state, factor, :in), transfers_part(state, factor, :out), counts_part(state, factor) ]
    parts.compact.reject { it.gross.zero? && it.net.zero? }
  end

  # What the purchases' part is made of: tare, damage and the rest
  # (humidity or yield other than the usual one, rounding).
  def purchases_breakdown(state)
    factor = self.class.factor(state)
    scope = purchases(state)
    gross, net, tare, damage = scope.pick(Arel.sql("COALESCE(SUM(gross_weight), 0)"), Arel.sql("COALESCE(SUM(net_weight), 0)"),
                                          Arel.sql("COALESCE(SUM(tare), 0)"), Arel.sql("COALESCE(SUM(damage_weight), 0)")).map(&:to_d)
    tare_effect = -(tare * factor).round(2)
    damage_effect = -damage.round(2)
    total = (net - (gross * factor)).round(2)
    { tare:, tare_effect:, damage:, damage_effect:, other_effect: (total - tare_effect - damage_effect).round(2), total:,
      counted: scope.where(weight_mode: "weighings").count, estimated: scope.where.not(weight_mode: "weighings").count }
  end

  private
    def lots = @lots ||= CoffeeLots.new.lots(warehouse_id: warehouse&.id)
    def until_moment = stock.date.in_time_zone.end_of_day
    def in_warehouse(scope, column = :warehouse_id) = warehouse ? scope.where(column => warehouse.id) : scope

    def purchases(state) = in_warehouse(Purchase.active.where(coffee_state: state, purchased_at: ..until_moment))

    def purchases_part(state, factor)
      gross, net = purchases(state).pick(Arel.sql("COALESCE(SUM(gross_weight), 0)"), Arel.sql("COALESCE(SUM(net_weight), 0)")).map(&:to_d)
      Part.new(key: :purchases, gross:, net:, effect: (net - (gross * factor)).round(2), items: [])
    end

    # Each shipment, the ones that move the difference the most first.
    def shipments_part(state, factor)
      scope = in_warehouse(Shipment.active.where(coffee_state: state, departed_at: ..until_moment))
      with_lots = CoffeeBatch.where.not(shipment_id: nil).distinct.pluck(:shipment_id).to_set
      items = scope.pluck(:id, :number, :departed_at, Arel.sql(Shipment::STOCK_NET_SQL), Arel.sql(Shipment::STOCK_GROSS_SQL)).filter_map do |id, number, at, net, gross|
        next if gross.nil?

        net = net.to_d
        gross = gross.to_d
        expected = (gross * factor).round(2)
        Item.new(label: format("%04d", number), at:, gross:, net:, expected:, effect: -(net - expected).round(2), with_lots: with_lots.include?(id), record: id)
      end
      items.sort_by! { -it.effect.abs }
      Part.new(key: :shipments, gross: -items.sum(0.to_d, &:gross), net: -items.sum(0.to_d, &:net), effect: items.sum(0.to_d, &:effect), items:)
    end

    def processes_part(state, factor, side)
      if side == :in
        scope = CoffeeConversion.active.where(to_state: state, finished_at: ..until_moment)
        scope = in_warehouse(scope, :output_warehouse_id)
        gross, net = scope.pick(Arel.sql("COALESCE(SUM(output_gross_weight), 0)"), Arel.sql("COALESCE(SUM(output_net_weight), 0)")).map(&:to_d)
        Part.new(key: :processes_in, gross:, net:, effect: (net - (gross * factor)).round(2), items: [])
      else
        scope = in_warehouse(CoffeeConversion.active.where(from_state: state, weighed_at: ..until_moment))
        gross, net = scope.pick(Arel.sql("COALESCE(SUM(input_gross_weight), 0)"), Arel.sql("COALESCE(SUM(input_net_weight), 0)")).map(&:to_d)
        Part.new(key: :processes_out, gross: -gross, net: -net, effect: -(net - (gross * factor)).round(2), items: [])
      end
    end

    # Physical counts' adjustments (StockCount): signed, as they came.
    def counts_part(state, factor)
      scope = in_warehouse(StockCount.active.where(coffee_state: state, counted_at: ..until_moment))
      gross, net = scope.pick(Arel.sql("COALESCE(SUM(gross_weight), 0)"), Arel.sql("COALESCE(SUM(net_weight), 0)")).map(&:to_d)
      Part.new(key: :counts, gross:, net:, effect: (net - (gross * factor)).round(2), items: [])
    end

    # Transfers only count within one warehouse.
    def transfers_part(state, factor, side)
      return unless warehouse

      moved = WarehouseTransfer.active.where(coffee_state: state, transferred_at: ..until_moment)
      moved = side == :in ? moved.where(to_warehouse_id: warehouse.id) : moved.where(from_warehouse_id: warehouse.id)
      gross, net = moved.pick(Arel.sql("COALESCE(SUM(gross_weight), 0)"), Arel.sql("COALESCE(SUM(net_weight), 0)")).map(&:to_d)
      sign = side == :in ? 1 : -1
      Part.new(key: :"transfers_#{side}", gross: sign * gross, net: sign * net, effect: sign * (net - (gross * factor)).round(2), items: [])
    end
end
