# Sales tab of a buyer: the current season by default.
class BuyerSaleFilter < ListFilter
  field :season_year, :id, default: -> { Season.current.year }
  field :payment_status, :choice, in: Sale::FILTER_STATUSES

  sorts(**SaleFilter::SORTS)

  def apply(scope)
    scope = scope.in_season(Season.new(season_year)) if season_year
    scope = payment_status ? scope.with_payment_status(payment_status) : scope.active
    scope.includes(:buyer, :payments).newest_first
  end
end
