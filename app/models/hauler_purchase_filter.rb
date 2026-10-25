# The purchases a hauler hauled, on their page.
class HaulerPurchaseFilter < ListFilter
  field :season_year, :id

  sorts purchased_at: "purchases.purchased_at",
        producer: { sql: text("people.first_names", "people.last_names"), joins: { producer: :person } },
        net_weight: "purchases.net_weight",
        price_per_pound: "purchases.hauler_price_per_pound",
        commission: "purchases.hauler_commission"

  def apply(scope)
    scope = scope.where(season_year:) if season_year
    scope.active.includes(producer: :person).newest_first
  end
end
