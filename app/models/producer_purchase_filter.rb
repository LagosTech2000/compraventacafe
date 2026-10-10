# Purchases tab of a producer: the current season by default.
class ProducerPurchaseFilter < ListFilter
  field :season_year, :id, default: -> { Season.current.year }
  field :invoiced, :choice, in: PurchaseFilter::INVOICED
  field :show_voided, :choice, in: %w[1]

  def apply(scope)
    scope = scope.where(season_year:) if season_year
    scope = invoiced == "yes" ? scope.where.not(invoice_id: nil) : scope.uninvoiced if invoiced
    scope = scope.active unless show_voided
    scope.includes(:invoice, :zone, producer: :person).newest_first
  end
end
