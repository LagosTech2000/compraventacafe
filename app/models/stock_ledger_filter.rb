# The kardex (Comercialización → Inventario): this month by default.
# Sorted in Ruby: the balance after each entry is computed in order.
class StockLedgerFilter < ListFilter
  field :from, :date, default: -> { Time.zone.today.beginning_of_month }
  field :to, :date, default: -> { Time.zone.today }
  field :coffee_state, :choice, in: Purchase::COFFEE_STATES
  field :warehouse_id, :id

  sorts at: { ruby: ->(entry) { entry.at } },
        kind: { ruby: ->(entry) { entry.kind } },
        who: { ruby: ->(entry) { StockLedgerFilter.who(entry) } },
        coffee_state: { ruby: ->(entry) { entry.human_coffee_state } },
        gross: { ruby: ->(entry) { entry.gross } },
        net: { ruby: ->(entry) { entry.net } },
        quintals: { ruby: ->(entry) { entry.quintals } },
        balance: { ruby: ->(entry) { entry.balance } }

  # Who an entry is with, to sort by it: the producer, the buyer, or the
  # conversion's number.
  def self.who(entry)
    case entry.kind
    when "purchase" then entry.record.producer.full_name
    when "shipment" then entry.record.buyer.name
    else entry.record.display_number
    end
  end

  def warehouse = @warehouse ||= warehouse_id && Warehouse.find_by(id: warehouse_id)
  def ledger = @ledger ||= StockLedger.new(from:, to: to || Time.zone.today, coffee_state:, warehouse:)

  # Newest first, as every list; each entry keeps the balance after it.
  def apply(_scope) = ledger.entries.reverse
end
