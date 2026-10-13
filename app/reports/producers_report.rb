# Producers and what they sold in the period: the ranking, who stopped
# selling (days since their last purchase, ever) and what is still owed to
# them. The period narrows their purchases, not the producers.
class ProducersReport < Report
  ACTIVITIES = %w[with_purchases without_purchases].freeze
  QUINTAL = PurchaseCalculation::QUINTAL_WEIGHT
  # Owed to the producer: purchases not invoiced or with the invoice not
  # fully paid (pending or partial), less what they paid with coffee to their
  # loans and what was already paid on those invoices.
  PENDING = <<~SQL.squish.freeze
    LEFT JOIN (
      SELECT owed.producer_id, owed.amount - COALESCE(paid.amount, 0) AS amount
      FROM (
        SELECT purchases.producer_id, SUM(purchases.total) - COALESCE(SUM(coffee.amount), 0) AS amount
        FROM purchases
        LEFT JOIN invoices ON invoices.id = purchases.invoice_id
        LEFT JOIN (SELECT purchase_id, SUM(amount) AS amount FROM loan_payments GROUP BY purchase_id) coffee
          ON coffee.purchase_id = purchases.id
        WHERE purchases.voided_at IS NULL AND (purchases.invoice_id IS NULL OR invoices.payment_status IN ('pending', 'partial'))
        GROUP BY purchases.producer_id
      ) owed
      LEFT JOIN (
        SELECT invoices.producer_id, SUM(invoice_payments.amount) AS amount
        FROM invoice_payments JOIN invoices ON invoices.id = invoice_payments.invoice_id
        WHERE invoices.payment_status = 'partial'
        GROUP BY invoices.producer_id
      ) paid ON paid.producer_id = owed.producer_id
    ) pending ON pending.producer_id = producers.id
    LEFT JOIN (
      SELECT producer_id, MAX(purchased_at) AS purchased_at FROM purchases WHERE voided_at IS NULL GROUP BY producer_id
    ) latest ON latest.producer_id = producers.id
  SQL
  LAST_DATE = "(latest.purchased_at AT TIME ZONE 'UTC' AT TIME ZONE '#{Time.zone.tzinfo.name}')::date".freeze
  NAME = "people.first_names || ' ' || people.last_names".freeze

  self.module_key = "trading"
  self.date_column = "purchases.purchased_at"
  self.date_type = :datetime
  self.default_period = "this_season"
  self.default_sort = :quintals
  self.default_measure = :quintals

  filter :q, :text
  filter :zone_id, :id
  filter :kind, :choice, in: Producer::KINDS
  filter :activity, :choice, in: ACTIVITIES

  detail { |producer| trading_producer_path(producer) }

  column(:producer, :text, sort: "people.last_names", &:full_name)
  column(:kind, :text, sort: "producers.kind", priority: 3, &:human_kind)
  column(:zone, :text, sort: "zones.name", priority: 3) { |producer| producer.zone&.name }
  column(:purchases_count, :integer, sort: "stats.purchases_count", priority: 2) { |producer| producer.purchases_count.to_i }
  column(:quintals, :quintals, sort: "stats.net_weight") { |producer| producer.net_weight.to_d / QUINTAL }
  column(:total, :money, sort: "stats.total", priority: 2) { |producer| producer.total.to_d }
  column(:average_price, :money, sort: "stats.total / NULLIF(stats.net_weight, 0)", priority: 3) do |producer|
    producer.total.to_d / producer.net_weight.to_d if producer.net_weight.to_d.positive?
  end
  column(:last_purchase_on, :date, sort: LAST_DATE, priority: 2, &:last_purchase_on)
  column(:days_since, :integer, sort: "CURRENT_DATE - #{LAST_DATE}") do |producer|
    (Time.zone.today - producer.last_purchase_on).to_i if producer.last_purchase_on
  end
  column(:pending, :money, sort: "pending.amount", priority: 2) { |producer| producer.pending_amount }

  measure :producers, :integer, "COUNT(*)"
  measure :selling, :integer, "COUNT(*) FILTER (WHERE stats.purchases_count > 0)"
  measure :purchases_count, :integer, "COALESCE(SUM(stats.purchases_count), 0)"
  measure :quintals, :quintals, "COALESCE(SUM(stats.net_weight), 0) / #{QUINTAL}"
  measure :total, :money, "COALESCE(SUM(stats.total), 0)"
  measure :pending, :money, "COALESCE(SUM(pending.amount), 0)"

  group :zone, sql: "people.zone_id", label_sql: "MIN(zones.name)"
  group :producer_kind, sql: "producers.kind", translate: ->(kind) { Producer.human_attribute_name("kind/#{kind}") }

  kpi :selling, :integer, "COUNT(*) FILTER (WHERE stats.purchases_count > 0)", good: :up
  kpi :quintals, :quintals, "COALESCE(SUM(stats.net_weight), 0) / #{QUINTAL}", good: :up
  kpi :average_quintals, :quintals,
      "COALESCE(SUM(stats.net_weight), 0) / #{QUINTAL} / NULLIF(COUNT(*) FILTER (WHERE stats.purchases_count > 0), 0)", good: :up
  kpi(:top_share, :percent, good: :down) { |relation, _| top_share(relation) }
  kpi :not_selling, :integer, "COUNT(*) FILTER (WHERE stats.purchases_count IS NULL)", good: :down
  kpi :pending, :money, "COALESCE(SUM(pending.amount), 0)", compare: false

  def scope = Producer.all

  # Producers with what they sold in the period.
  def records(in_period = period)
    stats = within(Purchase.active, in_period).group(:producer_id)
                                              .select(:producer_id, "COUNT(*) AS purchases_count",
                                                      "SUM(purchases.net_weight) AS net_weight", "SUM(purchases.total) AS total")
    apply_filters(Producer.joins(:person).joins("LEFT JOIN zones ON zones.id = people.zone_id").joins(PENDING)
                          .joins("LEFT JOIN (#{stats.to_sql}) stats ON stats.producer_id = producers.id"))
  end

  def apply_filters(relation)
    relation = relation.where(person_id: people_matching(filter.q)) if filter.q
    relation = relation.where(people: { zone_id: filter.zone_id }) if filter.zone_id
    relation = relation.where(kind: filter.kind) if filter.kind
    relation = relation.where("stats.purchases_count > 0") if filter.activity == "with_purchases"
    relation = relation.where("stats.purchases_count IS NULL") if filter.activity == "without_purchases"
    relation
  end

  def charts
    relation = records.where("stats.purchases_count > 0")
    top = breakdown(relation, "producers.id", "SUM(stats.net_weight) / #{QUINTAL}", label_sql: "MIN(#{NAME})", limit: 20, others: false)
    names, quintals, shares = pareto(top, plain(relation).pick(Arel.sql("SUM(stats.net_weight) / #{QUINTAL}")))
    kinds = breakdown(relation, "producers.kind", "SUM(stats.net_weight) / #{QUINTAL}", translate: human(Producer, :kind))
    zones = breakdown(relation, "people.zone_id", "SUM(stats.net_weight) / #{QUINTAL}", label_sql: "MIN(zones.name)")
    recency = plain(records).group(Arel.sql(LAST_DATE)).pluck(Arel.sql(LAST_DATE), Arel.sql("COUNT(*)"))
    never = recency.sum { |date, count| date ? 0 : count }
    ages = age_buckets(recency.select(&:first).map { |date, count| [ (today - date).to_i, count ] }, [ 0, 8, 31, 91 ])
    ages << [ I18n.t("reports.types.producers.never"), never ] if never.positive?

    [
      chart(:ranking, :pareto, labels: names, datasets: [ dataset(:quintals, quintals, format: :quintals),
                                                          dataset(:share, shares, format: :percent, kind: :line, axis: :y2) ], wide: true),
      chart(:recency, :bar, labels: ages.map(&:first), datasets: [ dataset(:producers, ages.map(&:last), format: :integer) ]),
      chart(:kinds, :doughnut, labels: kinds.map(&:first), datasets: [ dataset(:quintals, kinds.map(&:last), format: :quintals) ]),
      chart(:zones, :hbar, labels: zones.map(&:first), datasets: [ dataset(:quintals, zones.map(&:last), format: :quintals) ])
    ]
  end

  private
    def preload(relation)
      relation.includes(:zone, :person)
              .select("producers.*", "stats.purchases_count", "stats.net_weight", "stats.total",
                      "pending.amount AS pending_amount", "#{LAST_DATE} AS last_purchase_on")
    end

    # Share of the quintals sold by the 10 producers who sold the most.
    def top_share(relation)
      sold = relation.where("stats.purchases_count > 0").pluck(Arel.sql("stats.net_weight")).map(&:to_d).sort.reverse
      total = sold.sum
      (sold.first(10).sum / total * 100).round(1) if total.positive?
    end
end
