# The coffee in stock lot by lot (client, 2026-10-26): what came in (a
# purchase, or the result of a conversion) and how much of it is left,
# where, and since when.
#
# Every move is replayed in the order it happened, up to a moment (now by
# default). Coffee leaves the oldest lots first (client: «se priorizan las
# compras más viejas»), counted in net pounds: shipments by their local
# net, conversions by the net that went in, transfers by their net. What a
# lot loses of its sacks, damage and value goes with the share of net
# pounds taken (decision of implementation, pending to confirm). A transfer
# moves parts of lots to the other warehouse; each part keeps where it came
# from and its date.
#
# Nothing is stored: voiding or correcting a move changes the lots at once.
# Taking more than there is leaves a part without a lot (`shortfall`), as
# the stock may go below zero.
#
# Value (client, 2026-10-26, «Valor del inventario»): what was paid to the
# producers (the purchase's total) plus what was added to it: the hauler's
# commission of the purchase and, on a conversion's result, the cost of
# what went in plus the processing costs. Fuel, staff and vehicle upkeep
# are pending (question 23).
class CoffeeLots
  EPSILON = BigDecimal("0.005")
  # Same moment: what comes in first.
  ORDER = { purchase: 0, result: 1, transfer: 2, input: 3, shipment: 4, late_result: 5 }.freeze

  class Lot
    attr_reader :source, :coffee_state, :warehouse_id, :entered_at, :net_in, :transfer
    attr_accessor :net, :sacks, :damage, :purchase_value, :costs

    def initialize(source:, coffee_state:, warehouse_id:, entered_at:, net:, sacks:, damage:, purchase_value:, costs:, transfer: nil)
      @source = source
      @coffee_state = coffee_state
      @warehouse_id = warehouse_id
      @entered_at = entered_at
      @net_in = @net = net.to_d
      @sacks = sacks.to_d
      @damage = damage.to_d
      @purchase_value = purchase_value.to_d
      @costs = costs.to_d
      @transfer = transfer
    end

    def purchase? = source.is_a?(Purchase)
    def value = purchase_value + costs
    def quintals = PurchaseCalculation.quintals(net)
    def left? = net > EPSILON
    def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
    def key = [ source.class.name.underscore, source.id, transfer&.id ].compact.join("_")

    # Hours since it came in (into the business: a transferred part keeps
    # the date of its purchase or conversion).
    def hours(now = Time.current) = ((now - entered_at) / 1.hour).floor
    def days(now = Time.current) = (now.to_date - entered_at.in_time_zone.to_date).to_i

    # Takes up to `amount` net pounds: a Portion with its share of the rest.
    def take(amount)
      taken = [ amount, net ].min
      share = net.positive? ? taken / net : 0
      portion = Portion.new(lot: self, net: taken, sacks: (sacks * share).round(4), damage: (damage * share).round(2),
                            purchase_value: (purchase_value * share).round(2), costs: (costs * share).round(2))
      self.net -= taken
      self.sacks -= portion.sacks
      self.damage -= portion.damage
      self.purchase_value -= portion.purchase_value
      self.costs -= portion.costs
      portion
    end
  end

  # What a move took from one lot (lot nil: taken with no lot to take from).
  Portion = Data.define(:lot, :net, :sacks, :damage, :purchase_value, :costs) do
    def value = purchase_value + costs
    def shortfall? = lot.nil?
  end

  Totals = Data.define(:net, :sacks, :damage, :purchase_value, :costs, :count) do
    def value = purchase_value + costs
    def quintals = PurchaseCalculation.quintals(net)
    # Lempiras per net pound; nil without coffee.
    def cost_per_pound = net.positive? ? (value / net).round(2) : nil
  end

  attr_reader :at

  # Loads what the screens show of each lot's origin (the producer of a
  # purchase), in one go.
  def self.preload(lots)
    purchases = lots.map(&:source).grep(Purchase)
    ActiveRecord::Associations::Preloader.new(records: purchases, associations: { producer: :person }).call if purchases.any?
    lots
  end

  def initialize(at: Time.current)
    @at = at
  end

  # Lots with coffee left, the oldest first.
  def lots(coffee_state: nil, warehouse_id: nil)
    replay
    @queues.flat_map { |(state, warehouse), queue| coffee_state.in?([ nil, state ]) && warehouse_id.in?([ nil, warehouse ]) ? queue.select(&:left?) : [] }
           .sort_by { [ it.entered_at, it.source.id ] }
  end

  def totals(lots) = Totals.new(net: lots.sum(0.to_d, &:net), sacks: lots.sum(0.to_d, &:sacks), damage: lots.sum(0.to_d, &:damage),
                                purchase_value: lots.sum(0.to_d, &:purchase_value), costs: lots.sum(0.to_d, &:costs), count: lots.size)

  # What a shipment, a conversion (what went in) or a transfer took, lot by lot.
  def portions_for(record)
    replay
    @portions[[ record.class.name, record.id ]] || []
  end

  # What is being converted: the portions of the conversions not finished yet.
  def in_process(warehouse_id: nil)
    replay
    @in_process.select { |conversion| warehouse_id.nil? || conversion.warehouse_id == warehouse_id }
               .flat_map { portions_for(it) }
  end

  private
    def replay
      return if @queues

      @queues = Hash.new { |hash, key| hash[key] = [] }
      @portions = {}
      @in_process = []
      events.sort_by { |time, order, id, _| [ time, order, id ] }.each { |*, apply| apply.call }
    end

    def events
      purchase_events + conversion_events + transfer_events + shipment_events
    end

    def purchase_events
      Purchase.active.where(purchased_at: ..at)
              .select(:id, :purchased_at, :coffee_state, :warehouse_id, :net_weight, :sacks, :damage_weight, :total, :hauler_commission, :producer_id)
              .map do |purchase|
        [ purchase.purchased_at, ORDER[:purchase], purchase.id, lambda {
          add(Lot.new(source: purchase, coffee_state: purchase.coffee_state, warehouse_id: purchase.warehouse_id, entered_at: purchase.purchased_at,
                      net: purchase.net_weight, sacks: purchase.sacks, damage: purchase.damage_weight, purchase_value: purchase.total,
                      costs: purchase.hauler_commission))
        } ]
      end
    end

    def conversion_events
      costs = CoffeeConversion.processing_costs_by_conversion
      CoffeeConversion.active.where(weighed_at: ..at).flat_map do |conversion|
        input = [ conversion.weighed_at, ORDER[:input], conversion.id, lambda {
          take(conversion, conversion.from_state, conversion.warehouse_id, conversion.input_net_weight)
        } ]
        finished = conversion.finished_at && conversion.finished_at <= at
        @in_process << conversion unless finished
        next [ input ] unless finished

        late = conversion.finished_at <= conversion.weighed_at
        result = [ late ? conversion.weighed_at : conversion.finished_at, ORDER[late ? :late_result : :result], conversion.id, lambda {
          taken = portions_for(conversion)
          add(Lot.new(source: conversion, coffee_state: conversion.to_state, warehouse_id: conversion.output_warehouse_id || conversion.warehouse_id,
                      entered_at: conversion.finished_at, net: conversion.output_net_weight, sacks: conversion.output_sacks.to_i,
                      damage: conversion.output_damage_weight, purchase_value: taken.sum(0.to_d, &:purchase_value),
                      costs: taken.sum(0.to_d, &:costs) + costs.fetch(conversion.id, 0)))
        } ]
        [ input, result ]
      end
    end

    def transfer_events
      WarehouseTransfer.active.where(transferred_at: ..at).map do |transfer|
        [ transfer.transferred_at, ORDER[:transfer], transfer.id, lambda {
          take(transfer, transfer.coffee_state, transfer.from_warehouse_id, transfer.net_weight).each do |portion|
            next if portion.shortfall?

            add(Lot.new(source: portion.lot.source, coffee_state: transfer.coffee_state, warehouse_id: transfer.to_warehouse_id,
                        entered_at: portion.lot.entered_at, net: portion.net, sacks: portion.sacks, damage: portion.damage,
                        purchase_value: portion.purchase_value, costs: portion.costs, transfer:))
          end
        } ]
      end
    end

    def shipment_events
      Shipment.active.where(departed_at: ..at).select(:id, :departed_at, :coffee_state, :warehouse_id, :origin_net_weight).map do |shipment|
        [ shipment.departed_at, ORDER[:shipment], shipment.id, -> { take(shipment, shipment.coffee_state, shipment.warehouse_id, shipment.origin_net_weight) } ]
      end
    end

    # Keeps each warehouse's queue oldest first (a transferred part keeps its date).
    def add(lot)
      queue = @queues[[ lot.coffee_state, lot.warehouse_id ]]
      index = queue.bsearch_index { |other| other.entered_at > lot.entered_at } || queue.size
      queue.insert(index, lot)
    end

    def take(record, coffee_state, warehouse_id, amount)
      rest = amount.to_d
      portions = []
      @queues[[ coffee_state, warehouse_id ]].each do |lot|
        break unless rest > EPSILON
        next unless lot.left?

        portion = lot.take(rest)
        rest -= portion.net
        portions << portion
      end
      portions << Portion.new(lot: nil, net: rest, sacks: 0, damage: 0, purchase_value: 0, costs: 0) if rest > EPSILON
      @portions[[ record.class.name, record.id ]] = portions
    end
end
