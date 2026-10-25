# The kardex (Comercialización → Inventario): this month by default.
# Sorted in Ruby: the balance after each entry is computed in order.
class StockLedgerFilter < ListFilter
  field :from, :date, default: -> { Time.zone.today.beginning_of_month }
  field :to, :date, default: -> { Time.zone.today }
  field :coffee_state, :choice, in: Purchase::COFFEE_STATES

  sorts at: { ruby: ->(entry) { entry.at } },
        kind: { ruby: ->(entry) { entry.kind } },
        who: { ruby: ->(entry) { entry.kind == "purchase" ? entry.record.producer.full_name : entry.record.buyer.name } },
        coffee_state: { ruby: ->(entry) { entry.human_coffee_state } },
        pounds_in: { ruby: ->(entry) { entry.pounds_in } },
        pounds_out: { ruby: ->(entry) { entry.pounds_out } },
        balance: { ruby: ->(entry) { entry.balance } }

  def ledger = @ledger ||= StockLedger.new(from:, to: to || Time.zone.today, coffee_state:)

  # Newest first, as every list; each entry keeps the balance after it.
  def apply(_scope) = ledger.entries.reverse
end
