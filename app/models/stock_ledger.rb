# The coffee's kardex (Comercialización → Inventario): every purchase that
# came in and every shipment that left, between two dates, with the balance
# after each one, by coffee state. Voided ones are left out, as in the stock.
# The balance before the first day comes from CoffeeStock.
class StockLedger
  Entry = Data.define(:kind, :record, :at, :coffee_state, :pounds_in, :pounds_out, :balance) do
    def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
  end

  attr_reader :from, :to, :coffee_state

  def initialize(from:, to:, coffee_state: nil)
    @from = from
    @to = to
    @coffee_state = coffee_state
  end

  # Net pounds in stock when the period begins (end of the day before).
  def opening
    @opening ||= opening_stock.rows.select { |row| coffee_state.nil? || row.coffee_state == coffee_state }.sum(&:stock)
  end

  def closing = entries.last&.balance || opening
  def pounds_in = entries.sum(&:pounds_in)
  def pounds_out = entries.sum(&:pounds_out)

  # Oldest first, each with the balance after it (of its state, or of all
  # when no state is chosen).
  def entries
    @entries ||= begin
      balances = Hash.new(0)
      opening_stock.rows.each { |row| balances[row.coffee_state] = row.stock }
      moves.sort_by { |move| [ move[:at], move[:kind] == "purchase" ? 0 : 1, move[:record].id ] }.map do |move|
        balances[move[:coffee_state]] += move[:pounds_in] - move[:pounds_out]
        balance = coffee_state ? balances[coffee_state] : balances.values.sum
        Entry.new(**move, balance:)
      end
    end
  end

  private
    def opening_stock
      @opening_stock ||= CoffeeStock.new(from ? from - 1 : Date.new(2000, 1, 1))
    end

    def moves
      range = Purchase.day_range(from..to)
      purchases = Purchase.active.where(purchased_at: range).includes(producer: :person)
      shipments = Shipment.active.where(departed_at: range).includes(:buyer)
      if coffee_state
        purchases = purchases.where(coffee_state:)
        shipments = shipments.where(coffee_state:)
      end
      purchases.map { |purchase| { kind: "purchase", record: purchase, at: purchase.purchased_at, coffee_state: purchase.coffee_state,
                                   pounds_in: purchase.net_weight, pounds_out: 0 } } +
        shipments.map { |shipment| { kind: "shipment", record: shipment, at: shipment.departed_at, coffee_state: shipment.coffee_state,
                                     pounds_in: 0, pounds_out: shipment.origin_net_weight } }
    end
end
