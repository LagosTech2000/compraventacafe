# Shipments list (Comercialización → Salidas). Voided ones only with the
# "voided" status; "over tolerance" keeps the ones whose scales differ
# more than the site's tolerance.
class ShipmentFilter < ListFilter
  STATUSES = %w[in_transit received sold voided].freeze

  field :from, :date
  field :to, :date
  field :season_year, :id
  field :q, :text
  field :buyer_id, :id
  field :coffee_state, :choice, in: Purchase::COFFEE_STATES
  field :status, :choice, in: STATUSES
  field :over_tolerance, :choice, in: %w[1]

  DIFFERENCE_PERCENT = <<~SQL.squish.freeze
    CASE WHEN shipments.origin_net_weight > 0 AND shipments.destination_net_weight IS NOT NULL
    THEN (shipments.destination_net_weight - shipments.origin_net_weight) * 100 / shipments.origin_net_weight END
  SQL

  SORTS = {
    number: "shipments.number", departed_at: "shipments.departed_at",
    buyer: { sql: text("buyers.name"), joins: :buyer },
    coffee_state: "shipments.coffee_state", remission: "shipments.remission_number",
    origin_net: "shipments.origin_net_weight", sacks: "shipments.origin_sacks",
    destination_net: "shipments.destination_net_weight",
    difference: "shipments.destination_net_weight - shipments.origin_net_weight",
    difference_percent: DIFFERENCE_PERCENT,
    status: %w[shipments.voided_at shipments.received_on]
  }.freeze
  sorts(**SORTS)

  def apply(scope)
    scope = scope.on(from..to) if from || to
    scope = scope.where(season_year:) if season_year
    scope = search(scope) if q
    scope = scope.where(buyer_id:) if buyer_id
    scope = scope.where(coffee_state:) if coffee_state
    scope = status ? scope.with_status(status) : scope.active
    scope = scope.where("ABS(#{DIFFERENCE_PERCENT}) > ?", WeightTolerance.percent) if over_tolerance && WeightTolerance.percent
    scope.includes(:buyer, :active_sale_line, :sale).newest_first
  end

  private
    def search(scope)
      text = like(q)
      number = q.to_s.delete("^0-9").presence&.to_i
      conditions = scope.where(buyer_id: Buyer.where("buyers.name ILIKE ?", text).select(:id))
                        .or(scope.where("shipments.remission_number ILIKE ? OR shipments.weight_note_number ILIKE ? OR shipments.carrier_name ILIKE ?",
                                        text, text, text))
      number ? conditions.or(scope.where(number:)) : conditions
    end
end
