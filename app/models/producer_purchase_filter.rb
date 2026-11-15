# Purchases tab of a producer: the current season by default.
class ProducerPurchaseFilter < ListFilter
  field :season_year, :id, default: -> { Season.current.year }
  field :status, :choice, in: Purchase::STATUSES

  sorts(**PurchaseFilter::SORTS)

  def apply(scope)
    scope = scope.where(season_year:) if season_year
    scope = scope.merge(Purchase.with_status(status))
    scope.includes(:invoice, :zone, :farm, :loan_payments, producer: :person).newest_first
  end
end
