# Purchases list. With no params it shows today, like the daily screen.
# Voided purchases only by «Estado» (Fernando, 2026-11-13: anuladas or all
# the states; the voided checkbox is gone).
class PurchaseFilter < ListFilter
  field :from, :date, default: -> { Time.zone.today }
  field :to, :date, default: -> { Time.zone.today }
  field :season_year, :id
  field :q, :text
  field :zone_id, :id
  field :coffee_state, :choice, in: Purchase::COFFEE_STATES
  field :status, :choice, in: Purchase::STATUSES

  # Every column of the purchases table (also on a producer's page).
  SORTS = {
    number: "purchases.id", purchased_at: "purchases.purchased_at",
    producer: { sql: text("people.first_names", "people.last_names"), joins: { producer: :person } },
    coffee_state: "purchases.coffee_state", gross: "purchases.gross_weight", humidity: "purchases.humidity_percent",
    # QQ = net ÷ 125: the same order as the net weight.
    net: "purchases.net_weight", quintals: "purchases.net_weight", price: "purchases.price_per_pound",
    total: "purchases.total", invoice: { sql: "invoices.number", joins: :invoice }
  }.freeze
  sorts(**SORTS)

  def apply(scope)
    scope = scope.on(from..to) if from || to
    scope = scope.where(season_year:) if season_year
    scope = scope.where(producer_id: Producer.joins(:person).merge(Person.search(q)).select(:id)) if q
    scope = scope.where(zone_id:) if zone_id
    scope = scope.where(coffee_state:) if coffee_state
    scope = scope.merge(Purchase.with_status(status))
    scope.includes(:invoice, :zone, :farm, :loan_payments, producer: :person).newest_first
  end
end
