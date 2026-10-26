# Coffee sold (Comercialización): the buyer's net, quintals (each sale's own), the
# money, what was collected and what is owed, and how long buyers take to
# pay. Voided sales are left out.
class SalesReport < Report
  PAID_JOIN = <<~SQL.squish.freeze
    LEFT JOIN (SELECT sale_id, SUM(amount) AS amount FROM sale_payments GROUP BY sale_id) sale_paid ON sale_paid.sale_id = sales.id
  SQL
  PAID = "COALESCE(sale_paid.amount, 0)".freeze
  BALANCE = "(sales.total - #{PAID})".freeze
  UNPAID = "sales.payment_status IN ('pending', 'partial')".freeze
  QUINTALS = "SUM(sales.net_weight / sales.quintal_pounds)".freeze
  DIFFERENCE = "(sales.net_weight - sales.origin_net_weight)".freeze
  DIFFERENCE_PERCENT = "SUM(#{DIFFERENCE}) * 100 / NULLIF(SUM(sales.origin_net_weight), 0)".freeze
  PRICE_PER_QUINTAL = "SUM(sales.total) / NULLIF(SUM(sales.net_weight / sales.quintal_pounds), 0)".freeze
  DAYS_TO_PAY = "(sales.paid_on - sales.sold_on)".freeze
  STATUS_TONES = InvoicesReport::STATUS_TONES

  self.module_key = "sales"
  self.date_column = "sales.sold_on"
  self.default_period = "this_month"
  self.default_sort = :number
  self.default_measure = :total

  filter :q, :text
  filter :buyer_id, :id
  filter :coffee_state, :choice, in: Purchase::COFFEE_STATES
  filter :payment_status, :choice, in: Invoice::FILTER_STATUSES

  detail { |sale| sales_sale_path(sale) }

  column(:number, :text, sort: "sales.number", &:display_number)
  column(:sold_on, :date, sort: "sales.sold_on")
  column(:buyer, :text, sort: "buyers.name") { |sale| sale.buyer.name }
  column(:coffee_state, :text, sort: "sales.coffee_state", priority: 3, &:human_coffee_state)
  column(:buyer_document_number, :text, sort: "sales.buyer_document_number", priority: 3)
  column(:net_weight, :pounds, sort: "sales.net_weight", priority: 3)
  column(:quintals, :quintals, sort: "sales.net_weight", &:quintals)
  column(:unit_price, :text, sort: "sales.unit_price", priority: 2) { |sale| "#{ActiveSupport::NumberHelper.number_to_currency(sale.unit_price)} #{sale.human_price_unit.downcase}" }
  column(:difference_percent, :percent, sort: "#{DIFFERENCE} / NULLIF(sales.origin_net_weight, 0)", priority: 2, &:difference_percent)
  column(:total, :money, sort: "sales.total")
  column(:paid, :money, sort: PAID, priority: 3) { |sale| sale.paid_sum.to_d }
  column(:balance, :money, sort: BALANCE) { |sale| sale.total - sale.paid_sum.to_d }
  column(:payment_status, :badge, sort: "sales.payment_status") { |sale| [ sale.human_payment_status, STATUS_TONES.fetch(sale.payment_status) ] }
  column(:days, :integer, sort: "COALESCE(sales.paid_on, CURRENT_DATE) - sales.sold_on", priority: 3) do |sale|
    ((sale.paid_on || Time.zone.today) - sale.sold_on).to_i
  end

  measure :count, :integer, "COUNT(*)"
  measure :net_weight, :pounds, "SUM(sales.net_weight)"
  measure :quintals, :quintals, QUINTALS
  measure :price_per_quintal, :money, PRICE_PER_QUINTAL
  measure :difference_percent, :percent, DIFFERENCE_PERCENT
  measure :total, :money, "SUM(sales.total)"
  measure :paid, :money, "SUM(#{PAID})"
  measure :pending, :money, "COALESCE(SUM(#{BALANCE}) FILTER (WHERE #{UNPAID}), 0)"

  group :week, unit: "week"
  group :month, unit: "month"
  group :buyer, sql: "sales.buyer_id", label_sql: "MIN(buyers.name)"
  group :coffee_state, sql: "sales.coffee_state", translate: ->(state) { Purchase.human_attribute_name("coffee_state/#{state}") }
  group :payment_status, sql: "sales.payment_status", translate: ->(status) { Sale.human_attribute_name("payment_status/#{status}") }

  kpi :count, :integer, "COUNT(*)", good: :up
  kpi :quintals, :quintals, QUINTALS, good: :up
  kpi :total, :money, "SUM(sales.total)", good: :up
  kpi :price_per_quintal, :money, PRICE_PER_QUINTAL, good: :up
  kpi :paid, :money, "SUM(#{PAID})", good: :up
  kpi :pending, :money, "COALESCE(SUM(#{BALANCE}) FILTER (WHERE #{UNPAID}), 0)", good: :down
  kpi :difference_percent, :percent, DIFFERENCE_PERCENT
  kpi :average_days, :number, "AVG(#{DAYS_TO_PAY})", good: :down

  def scope
    Sale.active.joins(:buyer).joins(PAID_JOIN)
  end

  def apply_filters(relation)
    if filter.q
      by_text = relation.where("buyers.name ILIKE :q OR sales.buyer_document_number ILIKE :q", q: like(filter.q))
      relation = filter.q.match?(/\A\d+\z/) ? by_text.or(relation.where(number: filter.q.to_i)) : by_text
    end
    relation = relation.where(buyer_id: filter.buyer_id) if filter.buyer_id
    relation = relation.where(coffee_state: filter.coffee_state) if filter.coffee_state
    relation = filter.payment_status == "unpaid" ? relation.where(UNPAID) : relation.where(payment_status: filter.payment_status) if filter.payment_status
    relation
  end

  def charts
    relation = records
    status = human(Sale, :payment_status)
    labels, by_status = over_time_by(relation, "sales.payment_status", "SUM(sales.total)", translate: status)
    price_labels, prices = over_time(relation, { price_per_quintal: PRICE_PER_QUINTAL, quintals: QUINTALS }, gaps: nil)
    buyers = breakdown(relation, "sales.buyer_id", "SUM(sales.total)", label_sql: "MIN(buyers.name)")
    debtors = breakdown(relation.where(UNPAID), "sales.buyer_id", "SUM(#{BALANCE})", label_sql: "MIN(buyers.name)", limit: 10, others: false)
    pending = plain(relation).where(UNPAID).group(:sold_on).pluck(:sold_on, Arel.sql("SUM(#{BALANCE})"))
    ages = age_buckets(pending.map { |date, amount| [ (today - date).to_i, amount ] }, [ 0, 8, 16, 31, 61 ])
    methods = SalePayment.where(sale_id: plain(relation).select(:id)).group(:payment_method).order(Arel.sql("SUM(amount) DESC"))
                         .sum(:amount).map { |method, amount| [ SalePayment.human_method(method), number(amount) ] }

    [
      chart(:by_status, :stacked, labels:, datasets: by_status.map { |set| set.merge(format: :money) }, wide: true,
                                  tones: { status.call("pending") => "danger", status.call("partial") => "warning", status.call("paid") => "success" }),
      chart(:prices, :combo, labels: price_labels, datasets: [ dataset(:quintals, prices[:quintals], format: :quintals),
                                                              dataset(:price_per_quintal, prices[:price_per_quintal], format: :money, kind: :line, axis: :y2) ]),
      chart(:buyers, :hbar, labels: buyers.map(&:first), datasets: [ dataset(:total, buyers.map(&:last), format: :money) ]),
      chart(:debtors, :hbar, labels: debtors.map(&:first), datasets: [ dataset(:pending, debtors.map(&:last), format: :money) ]),
      chart(:pending_age, :bar, labels: ages.map(&:first), datasets: [ dataset(:pending, ages.map(&:last), format: :money) ]),
      chart(:methods, :doughnut, labels: methods.map(&:first), datasets: [ dataset(:paid, methods.map(&:last), format: :money) ])
    ]
  end

  private
    def preload(relation)
      relation.includes(:buyer).select("sales.*", "#{PAID} AS paid_sum")
    end
end
