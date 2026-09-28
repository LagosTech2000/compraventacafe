# Purchases list. With no params it shows today, like the daily screen.
class PurchaseFilter < ListFilter
  INVOICED = %w[yes no].freeze

  field :from, :date, default: -> { Time.zone.today }
  field :to, :date, default: -> { Time.zone.today }
  field :q, :text
  field :zone_id, :id
  field :coffee_state, :choice, in: Purchase::COFFEE_STATES
  field :invoiced, :choice, in: INVOICED

  def apply(scope)
    scope = scope.where(purchased_on: from..) if from
    scope = scope.where(purchased_on: ..to) if to
    scope = scope.where(producer_id: Producer.joins(:person).merge(Person.search(q)).select(:id)) if q
    scope = scope.where(zone_id:) if zone_id
    scope = scope.where(coffee_state:) if coffee_state
    scope = invoiced == "yes" ? scope.where.not(invoice_id: nil) : scope.uninvoiced if invoiced
    scope.includes(:invoice, :zone, producer: :person).newest_first
  end
end
