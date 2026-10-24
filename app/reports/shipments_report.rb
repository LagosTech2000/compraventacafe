# Trucks that left with coffee (Comercialización): the net on the local
# scale, the buyer's net and the difference between them. Voided ones are
# left out.
class ShipmentsReport < Report
  DIFFERENCE = "(shipments.destination_net_weight - shipments.origin_net_weight)".freeze
  RECEIVED = "shipments.destination_net_weight IS NOT NULL".freeze
  # Over the received ones only: the local net they left with.
  COMPARED_ORIGIN = "SUM(shipments.origin_net_weight) FILTER (WHERE #{RECEIVED})".freeze
  DIFFERENCE_PERCENT = "SUM(#{DIFFERENCE}) * 100 / NULLIF(#{COMPARED_ORIGIN}, 0)".freeze
  SOLD = "EXISTS (SELECT 1 FROM sale_lines WHERE sale_lines.shipment_id = shipments.id AND sale_lines.active)".freeze
  STATUS_TONES = { "in_transit" => "warning", "received" => "neutral", "sold" => "success" }.freeze
  STATUSES = %w[in_transit received sold].freeze

  self.module_key = "sales"
  self.date_column = "shipments.departed_at"
  self.date_type = :datetime
  self.default_period = "this_month"
  self.default_sort = :departed_at
  self.default_measure = :origin_net

  filter :q, :text
  filter :buyer_id, :id
  filter :coffee_state, :choice, in: Purchase::COFFEE_STATES
  filter :status, :choice, in: STATUSES
  filter :over_tolerance, :choice, in: %w[1]

  detail { |shipment| sales_shipment_path(shipment) }

  column(:number, :text, sort: "shipments.number", &:display_number)
  column(:departed_at, :datetime, sort: "shipments.departed_at")
  column(:buyer, :text, sort: "buyers.name") { |shipment| shipment.buyer.name }
  column(:coffee_state, :text, sort: "shipments.coffee_state", priority: 2, &:human_coffee_state)
  column(:remission_number, :text, sort: "shipments.remission_number", priority: 3)
  column(:weight_note_number, :text, sort: "shipments.weight_note_number", priority: 3)
  column(:sacks, :integer, sort: "shipments.origin_sacks", priority: 3, &:origin_sacks)
  column(:origin_net, :pounds, sort: "shipments.origin_net_weight", &:origin_net_weight)
  column(:destination_net, :pounds, sort: "shipments.destination_net_weight", &:destination_net_weight)
  column(:difference, :pounds, sort: DIFFERENCE, priority: 2, &:net_difference)
  column(:difference_percent, :percent, sort: "#{DIFFERENCE} / NULLIF(shipments.origin_net_weight, 0)", &:difference_percent)
  column(:status, :badge, sort: "shipments.received_on") { |shipment| [ shipment.human_status, STATUS_TONES.fetch(shipment.status, "neutral") ] }

  measure :count, :integer, "COUNT(*)"
  measure :sacks, :integer, "SUM(shipments.origin_sacks)"
  measure :origin_net, :pounds, "SUM(shipments.origin_net_weight)"
  measure :destination_net, :pounds, "SUM(shipments.destination_net_weight)"
  measure :difference, :pounds, "SUM(#{DIFFERENCE})"
  measure :difference_percent, :percent, DIFFERENCE_PERCENT

  group :day, unit: "day"
  group :week, unit: "week"
  group :month, unit: "month"
  group :buyer, sql: "shipments.buyer_id", label_sql: "MIN(buyers.name)"
  group :coffee_state, sql: "shipments.coffee_state", translate: ->(state) { Purchase.human_attribute_name("coffee_state/#{state}") }

  kpi :count, :integer, "COUNT(*)", good: :up
  kpi :origin_net, :pounds, "SUM(shipments.origin_net_weight)", good: :up
  kpi :destination_net, :pounds, "SUM(shipments.destination_net_weight)", good: :up
  kpi :difference, :pounds, "SUM(#{DIFFERENCE})"
  kpi :difference_percent, :percent, DIFFERENCE_PERCENT
  kpi :in_transit, :integer, "COUNT(*) FILTER (WHERE shipments.received_on IS NULL)", good: :down, compare: false

  def scope
    Shipment.active.joins(:buyer)
  end

  def apply_filters(relation)
    if filter.q
      text = like(filter.q)
      relation = relation.where("buyers.name ILIKE :q OR shipments.remission_number ILIKE :q OR shipments.weight_note_number ILIKE :q", q: text)
    end
    relation = relation.where(buyer_id: filter.buyer_id) if filter.buyer_id
    relation = relation.where(coffee_state: filter.coffee_state) if filter.coffee_state
    relation = case filter.status
    when "in_transit" then relation.where(received_on: nil)
    when "received" then relation.where.not(received_on: nil).where.not(SOLD)
    when "sold" then relation.where(SOLD)
    else relation
    end
    if filter.over_tolerance && (tolerance = WeightTolerance.percent)
      relation = relation.where("ABS(#{DIFFERENCE} * 100 / NULLIF(shipments.origin_net_weight, 0)) > ?", tolerance)
    end
    relation
  end

  def charts
    relation = records
    labels, weights = over_time(relation, { origin_net: "SUM(shipments.origin_net_weight)",
                                            destination_net: "COALESCE(SUM(shipments.destination_net_weight), 0)" })
    percent_labels, percent = over_time(relation.where(RECEIVED), { difference_percent: DIFFERENCE_PERCENT }, gaps: nil)
    buyers = breakdown(relation, "shipments.buyer_id", "SUM(shipments.origin_net_weight)", label_sql: "MIN(buyers.name)")
    differences = breakdown(relation.where(RECEIVED), "shipments.buyer_id", DIFFERENCE_PERCENT, label_sql: "MIN(buyers.name)", others: false)
                    .sort_by(&:last)
    states = breakdown(relation, "shipments.coffee_state", "SUM(shipments.origin_net_weight)", translate: human(Purchase, :coffee_state))

    [
      chart(:weights, :bar, labels:, datasets: [ dataset(:origin_net, weights[:origin_net], format: :pounds),
                                                dataset(:destination_net, weights[:destination_net], format: :pounds) ], wide: true),
      chart(:difference, :bar, labels: percent_labels, datasets: [ dataset(:difference_percent, percent[:difference_percent], format: :percent) ]),
      chart(:buyers, :hbar, labels: buyers.map(&:first), datasets: [ dataset(:origin_net, buyers.map(&:last), format: :pounds) ]),
      chart(:buyer_difference, :hbar, labels: differences.map(&:first),
                                      datasets: [ dataset(:difference_percent, differences.map(&:last), format: :percent) ]),
      chart(:states, :doughnut, labels: states.map(&:first), datasets: [ dataset(:origin_net, states.map(&:last), format: :pounds) ])
    ]
  end

  private
    def preload(relation)
      relation.includes(:buyer, :active_sale_line)
    end
end
