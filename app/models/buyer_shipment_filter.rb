# Shipments tab of a buyer: the current season by default.
class BuyerShipmentFilter < ListFilter
  field :season_year, :id, default: -> { Season.current.year }
  field :status, :choice, in: ShipmentFilter::STATUSES

  sorts(**ShipmentFilter::SORTS)

  def apply(scope)
    scope = scope.where(season_year:) if season_year
    scope = status ? scope.with_status(status) : scope.active
    scope.includes(:buyer, :active_sale_line, :sale).newest_first
  end
end
