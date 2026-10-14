# Coffee bought: every purchase not voided, by date and time of purchase.
class PurchasesReport < Report
  INVOICE_STATUSES = %w[uninvoiced pending partial paid].freeze
  QUINTALS = "SUM(purchases.net_weight) / #{PurchaseCalculation::QUINTAL_WEIGHT}".freeze
  AVERAGE_PRICE = "SUM(purchases.total) / NULLIF(SUM(purchases.net_weight), 0)".freeze
  INVOICE_STATUS = <<~SQL.squish.freeze
    CASE WHEN purchases.invoice_id IS NULL THEN 'uninvoiced' ELSE invoices.payment_status END
  SQL

  # Where the coffee comes from (map): the purchase's farm when it has a
  # point on the map, otherwise the producer's.
  FARM_LOCATED = "(farms.latitude IS NOT NULL AND farms.longitude IS NOT NULL)".freeze
  PRODUCER_NAME = "people.first_names || ' ' || people.last_names".freeze
  ORIGIN = {
    id: "CASE WHEN #{FARM_LOCATED} THEN 'farm-' || farms.id ELSE 'person-' || people.id END",
    label: "CASE WHEN #{FARM_LOCATED} THEN farms.name || ' · ' || #{PRODUCER_NAME} ELSE #{PRODUCER_NAME} END",
    latitude: "CASE WHEN #{FARM_LOCATED} THEN farms.latitude ELSE people.latitude END",
    longitude: "CASE WHEN #{FARM_LOCATED} THEN farms.longitude ELSE people.longitude END"
  }.freeze

  self.module_key = "trading"
  self.date_column = "purchases.purchased_at"
  self.date_type = :datetime
  self.default_period = "this_month"
  self.default_sort = :purchased_at
  self.default_measure = :quintals

  filter :q, :text
  filter :zone_id, :id
  filter :coffee_state, :choice, in: Purchase::COFFEE_STATES
  filter :invoice_status, :choice, in: INVOICE_STATUSES
  filter :producer_kind, :choice, in: Producer::KINDS
  filter :created_by_id, :id

  column(:purchased_at, :datetime, sort: "purchases.purchased_at")
  column(:producer, :text, sort: "people.last_names") { |purchase| purchase.producer.full_name }
  column(:zone, :text, sort: "zones.name", priority: 3) { |purchase| purchase.zone&.name }
  column(:coffee_state, :text, sort: "purchases.coffee_state", priority: 2, &:human_coffee_state)
  column(:gross_weight, :pounds, sort: "purchases.gross_weight", priority: 3)
  column(:humidity_percent, :percent, sort: "purchases.humidity_percent", priority: 3) { |purchase| purchase.humidity_percent unless purchase.cherry? }
  column(:quintals, :quintals, sort: "purchases.net_weight")
  column(:price_per_pound, :money, sort: "purchases.price_per_pound", priority: 2)
  column(:total, :money, sort: "purchases.total")
  column(:invoice, :badge, sort: "invoices.number", priority: 2) do |purchase|
    invoice = purchase.invoice
    if invoice
      [ "#{invoice.display_number} · #{invoice.human_payment_status}", InvoicesReport::STATUS_TONES.fetch(invoice.payment_status) ]
    else
      [ I18n.t("reports.types.purchases.uninvoiced"), "neutral" ]
    end
  end
  column(:created_by, :text, sort: "users.name", priority: 3) { |purchase| purchase.created_by.name }

  detail { |purchase| trading_purchase_path(purchase) }

  measure :count, :integer, "COUNT(*)"
  measure :quintals, :quintals, QUINTALS
  measure :total, :money, "SUM(purchases.total)"
  measure :average_price, :money, AVERAGE_PRICE
  measure :gross_weight, :pounds, "SUM(purchases.gross_weight)"
  measure :net_weight, :pounds, "SUM(purchases.net_weight)"
  measure :producers, :integer, "COUNT(DISTINCT purchases.producer_id)"

  group :day, unit: "day"
  group :week, unit: "week"
  group :month, unit: "month"
  group :season, sql: "purchases.season_year", translate: ->(year) { I18n.t("trading.season.name", season: Season.new(year).label) }
  group :producer, sql: "purchases.producer_id", label_sql: "MIN(people.first_names || ' ' || people.last_names)"
  group :zone, sql: "purchases.zone_id", label_sql: "MIN(zones.name)"
  group :coffee_state, sql: "purchases.coffee_state", translate: ->(state) { Purchase.human_attribute_name("coffee_state/#{state}") }
  group :invoice_status, sql: INVOICE_STATUS, translate: ->(status) { I18n.t("reports.types.purchases.invoice_statuses.#{status}") }
  group :producer_kind, sql: "producers.kind", translate: ->(kind) { Producer.human_attribute_name("kind/#{kind}") }
  group :created_by, sql: "purchases.created_by_id", label_sql: "MIN(users.name)"

  kpi :count, :integer, "COUNT(*)", good: :up
  kpi :quintals, :quintals, QUINTALS, good: :up
  kpi :total, :money, "SUM(purchases.total)"
  kpi :average_price, :money, AVERAGE_PRICE
  kpi :producers, :integer, "COUNT(DISTINCT purchases.producer_id)", good: :up
  kpi :uninvoiced, :money, "SUM(purchases.total) FILTER (WHERE purchases.invoice_id IS NULL)", compare: false

  def scope
    Purchase.active.joins(producer: :person).joins(:created_by).left_joins(:zone, :invoice)
  end

  def apply_filters(relation)
    relation = relation.where(producer_id: Producer.where(person_id: people_matching(filter.q)).select(:id)) if filter.q
    relation = relation.where(zone_id: filter.zone_id) if filter.zone_id
    relation = relation.where(coffee_state: filter.coffee_state) if filter.coffee_state
    relation = relation.where(producers: { kind: filter.producer_kind }) if filter.producer_kind
    relation = relation.where(created_by_id: filter.created_by_id) if filter.created_by_id
    relation = relation.where("#{INVOICE_STATUS} = ?", filter.invoice_status) if filter.invoice_status
    relation
  end

  def charts
    relation = records
    labels, series = over_time(relation, { quintals: QUINTALS, total: "SUM(purchases.total)" })
    price_labels, prices = over_time_by(relation, "purchases.coffee_state", AVERAGE_PRICE, translate: human(Purchase, :coffee_state), gaps: nil)
    producers = breakdown(relation, "purchases.producer_id", QUINTALS, label_sql: "MIN(people.first_names || ' ' || people.last_names)", limit: 15, others: false)
    names, quintals, shares = pareto(producers, relation.unscope(:order).pick(Arel.sql(QUINTALS)))
    zones = breakdown(relation, "purchases.zone_id", QUINTALS, label_sql: "MIN(zones.name)")
    states = breakdown(relation, "purchases.coffee_state", QUINTALS, translate: human(Purchase, :coffee_state))
    statuses = breakdown(relation, INVOICE_STATUS, "SUM(purchases.total)",
                         translate: ->(status) { I18n.t("reports.types.purchases.invoice_statuses.#{status}") })

    [
      chart(:volume, :combo, labels:, datasets: [ dataset(:quintals, series[:quintals], format: :quintals),
                                                  dataset(:total, series[:total], format: :money, kind: :line, axis: :y2) ], wide: true),
      chart(:price, :line, labels: price_labels, datasets: prices.map { |set| set.merge(format: :money) }),
      chart(:coffee_states, :doughnut, labels: states.map(&:first), datasets: [ dataset(:quintals, states.map(&:last), format: :quintals) ]),
      chart(:producers, :pareto, labels: names, datasets: [ dataset(:quintals, quintals, format: :quintals),
                                                            dataset(:share, shares, format: :percent, kind: :line, axis: :y2) ], wide: true),
      chart(:zones, :hbar, labels: zones.map(&:first), datasets: [ dataset(:quintals, zones.map(&:last), format: :quintals) ]),
      chart(:invoice_statuses, :doughnut, labels: statuses.map(&:first), datasets: [ dataset(:total, statuses.map(&:last), format: :money) ],
                                          tones: { status_label("uninvoiced") => "muted", status_label("pending") => "danger",
                                                   status_label("partial") => "warning", status_label("paid") => "success" }),
      chart(:humidity_price, :scatter, labels: [], datasets: humidity_price(relation)),
      chart(:arrivals, :heatmap, labels: [], datasets: [ { data: weekday_hours(relation) } ], wide: true),
      locations(:map, relation.left_joins(:farm), place: ORIGIN, measure: :quintals, sql: QUINTALS, format: :quintals,
                                                  link: :trading_producer_path, link_sql: "producers.id")
    ]
  end

  private
    def status_label(status) = I18n.t("reports.types.purchases.invoice_statuses.#{status}")

    def preload(relation) = relation.includes(:zone, :invoice, :created_by, producer: :person)

    # Price paid against humidity, one point per parchment purchase (the
    # latest 400), one series per state.
    def humidity_price(relation)
      %w[wet_parchment dry_parchment].map do |state|
        points = relation.where(coffee_state: state).where.not(humidity_percent: nil).reorder(purchased_at: :desc).limit(400)
                         .pluck(:humidity_percent, :price_per_pound).map { |x, y| { x: number(x), y: number(y) } }
        { label: Purchase.human_attribute_name("coffee_state/#{state}"), data: points, format: :money, x_format: :percent }
      end
    end
end
