# The coffee's kardex (Comercialización → Inventario): every purchase that
# came in, every shipment that left and every conversion (what went into it
# and what came out), between two dates, with the balance after each one,
# by coffee state, in gross and net pounds (and QQ). Voided ones are left
# out, as in the stock. The balance before the first day comes from
# CoffeeStock.
#
# Of one warehouse when given (client, 2026-10-26): then transfers in and
# out of it are moves too; of all of them they are not (the coffee stays).
class StockLedger
  KINDS = %w[purchase shipment conversion_out conversion_in transfer_in transfer_out].freeze
  # Same moment: what comes in first.
  ORDER = { "purchase" => 0, "conversion_in" => 1, "transfer_in" => 2, "transfer_out" => 3, "conversion_out" => 4, "shipment" => 5 }.freeze

  Entry = Data.define(:kind, :record, :at, :coffee_state, :pounds_in, :pounds_out, :gross_in, :gross_out, :balance, :gross_balance) do
    def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
    def in? = pounds_in.positive? || gross_in.positive?
    def net = pounds_in - pounds_out
    def gross = gross_in - gross_out
    def quintals = PurchaseCalculation.quintals(net)
    def key = "#{kind}_#{record.id}"
  end

  attr_reader :from, :to, :coffee_state, :warehouse

  def initialize(from:, to:, coffee_state: nil, warehouse: nil)
    @from = from
    @to = to
    @coffee_state = coffee_state
    @warehouse = warehouse
  end

  # Net and gross pounds in stock when the period begins (end of the day before).
  def opening = @opening ||= opening_rows.sum(&:stock)
  def gross_opening = @gross_opening ||= opening_rows.sum(&:gross_stock)

  def closing = entries.last&.balance || opening
  def gross_closing = entries.last&.gross_balance || gross_opening
  def pounds_in = entries.sum(&:pounds_in)
  def pounds_out = entries.sum(&:pounds_out)
  def gross_in = entries.sum(&:gross_in)
  def gross_out = entries.sum(&:gross_out)

  # Oldest first, each with the balance after it (of its state, or of all
  # when no state is chosen).
  def entries
    @entries ||= begin
      balances = Hash.new(0)
      gross_balances = Hash.new(0)
      opening_stock.rows.each do |row|
        balances[row.coffee_state] = row.stock
        gross_balances[row.coffee_state] = row.gross_stock
      end
      moves.sort_by { |move| [ move[:at], ORDER.fetch(move[:kind]), move[:record].id ] }.map do |move|
        balances[move[:coffee_state]] += move[:pounds_in] - move[:pounds_out]
        gross_balances[move[:coffee_state]] += move[:gross_in] - move[:gross_out]
        balance = coffee_state ? balances[coffee_state] : balances.values.sum
        gross_balance = coffee_state ? gross_balances[coffee_state] : gross_balances.values.sum
        Entry.new(**move, balance:, gross_balance:)
      end
    end
  end

  private
    def opening_stock
      @opening_stock ||= CoffeeStock.new(from ? from - 1 : Date.new(2000, 1, 1), warehouse:)
    end

    def opening_rows = opening_stock.rows.select { |row| coffee_state.nil? || row.coffee_state == coffee_state }

    def moves
      range = Purchase.day_range(from..to)
      purchases = Purchase.active.where(purchased_at: range).includes(producer: :person)
      shipments = Shipment.active.where(departed_at: range).includes(:buyer)
      weighed = CoffeeConversion.active.where(weighed_at: range)
      came_out = CoffeeConversion.active.where(finished_at: range)
      transfers_in = transfers_out = WarehouseTransfer.none
      if warehouse
        purchases = purchases.where(warehouse:)
        shipments = shipments.where(warehouse:)
        weighed = weighed.where(warehouse:)
        came_out = came_out.where(output_warehouse: warehouse)
        moved = WarehouseTransfer.active.where(transferred_at: range).includes(:from_warehouse, :to_warehouse)
        transfers_in = moved.where(to_warehouse: warehouse)
        transfers_out = moved.where(from_warehouse: warehouse)
      end
      if coffee_state
        purchases = purchases.where(coffee_state:)
        shipments = shipments.where(coffee_state:)
        weighed = weighed.where(from_state: coffee_state)
        came_out = came_out.where(to_state: coffee_state)
        transfers_in = transfers_in.where(coffee_state:)
        transfers_out = transfers_out.where(coffee_state:)
      end
      purchases.map { |purchase| move("purchase", purchase, purchase.purchased_at, purchase.coffee_state, net_in: purchase.net_weight, gross_in: purchase.gross_weight) } +
        shipments.map { |shipment| move("shipment", shipment, shipment.departed_at, shipment.coffee_state, net_out: shipment.origin_net_weight, gross_out: shipment.origin_gross_weight) } +
        weighed.map { |conversion| move("conversion_out", conversion, conversion.weighed_at, conversion.from_state, net_out: conversion.input_net_weight, gross_out: conversion.input_gross_weight) } +
        came_out.map { |conversion| move("conversion_in", conversion, conversion.finished_at, conversion.to_state, net_in: conversion.output_net_weight, gross_in: conversion.output_gross_weight) } +
        transfers_in.map { |transfer| move("transfer_in", transfer, transfer.transferred_at, transfer.coffee_state, net_in: transfer.net_weight, gross_in: transfer.gross_weight) } +
        transfers_out.map { |transfer| move("transfer_out", transfer, transfer.transferred_at, transfer.coffee_state, net_out: transfer.net_weight, gross_out: transfer.gross_weight) }
    end

    def move(kind, record, at, state, net_in: 0, net_out: 0, gross_in: 0, gross_out: 0)
      { kind:, record:, at:, coffee_state: state, pounds_in: net_in.to_d, pounds_out: net_out.to_d, gross_in: gross_in.to_d, gross_out: gross_out.to_d }
    end
end
