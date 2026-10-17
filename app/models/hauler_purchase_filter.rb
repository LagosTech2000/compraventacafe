# The purchases a hauler hauled, on their page.
class HaulerPurchaseFilter < ListFilter
  field :season_year, :id

  sorts purchased_at: "purchases.purchased_at",
        producer: { sql: text("people.first_names", "people.last_names"), joins: { producer: :person } },
        net_weight: "purchases.net_weight",
        cans: "purchases.hauler_cans",
        commission_percent: "purchases.hauler_commission_percent",
        can_price: "purchases.hauler_can_price",
        commission: "purchases.hauler_commission"

  def apply(scope)
    scope = scope.where(season_year:) if season_year
    scope.active.includes(producer: :person).newest_first
  end
end
