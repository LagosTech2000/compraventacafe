# Invoices given to producers: what they add up to, what was paid with
# coffee to their loans, what is left to pay them and how long it takes.
class InvoicesReport < Report
  TOTALS = <<~SQL.squish.freeze
    LEFT JOIN (
      SELECT purchases.invoice_id, COUNT(*) AS purchases_count, SUM(purchases.net_weight) AS net_weight, SUM(purchases.total) AS total
      FROM purchases WHERE purchases.invoice_id IS NOT NULL GROUP BY purchases.invoice_id
    ) invoice_totals ON invoice_totals.invoice_id = invoices.id
    LEFT JOIN (
      SELECT purchases.invoice_id, SUM(loan_payments.amount) AS amount
      FROM loan_payments JOIN purchases ON purchases.id = loan_payments.purchase_id
      WHERE purchases.invoice_id IS NOT NULL GROUP BY purchases.invoice_id
    ) invoice_coffee ON invoice_coffee.invoice_id = invoices.id
    LEFT JOIN (
      SELECT invoice_id, SUM(amount) AS amount FROM invoice_payments GROUP BY invoice_id
    ) invoice_paid ON invoice_paid.invoice_id = invoices.id
  SQL
  TOTAL = "COALESCE(invoice_totals.total, 0)".freeze
  COFFEE = "COALESCE(invoice_coffee.amount, 0)".freeze
  TO_PAY = "(#{TOTAL} - #{COFFEE})".freeze
  PAID = "COALESCE(invoice_paid.amount, 0)".freeze
  BALANCE = "(#{TO_PAY} - #{PAID})".freeze
  UNPAID = "invoices.payment_status IN ('pending', 'partial')".freeze
  STATUS_TONES = { "pending" => "danger", "partial" => "warning", "paid" => "success" }.freeze
  QUINTALS = "SUM(invoice_totals.net_weight) / #{PurchaseCalculation::QUINTAL_WEIGHT}".freeze
  DAYS_TO_PAY = "(invoices.paid_on - invoices.issued_on)".freeze

  self.module_key = "trading"
  self.date_column = "invoices.issued_on"
  self.default_period = "this_month"
  self.default_sort = :number
  self.default_measure = :to_pay

  filter :q, :text
  filter :payment_status, :choice, in: Invoice::FILTER_STATUSES
  filter :payment_method, :choice, in: Invoice::PAYMENT_METHODS
  filter :zone_id, :id

  detail { |invoice| trading_invoice_path(invoice) }

  column(:number, :text, sort: "invoices.number", &:display_number)
  column(:issued_on, :date, sort: "invoices.issued_on")
  column(:producer, :text, sort: "people.last_names") { |invoice| invoice.producer.full_name }
  column(:purchases_count, :integer, sort: "invoice_totals.purchases_count", priority: 3)
  column(:quintals, :quintals, sort: "invoice_totals.net_weight", priority: 2) do |invoice|
    invoice.net_weight_sum.to_d / PurchaseCalculation::QUINTAL_WEIGHT
  end
  column(:total, :money, sort: TOTAL, priority: 2, &:total_sum)
  column(:coffee, :money, sort: COFFEE, priority: 3, &:coffee_sum)
  column(:to_pay, :money, sort: TO_PAY, priority: 2) { |invoice| invoice.total_sum.to_d - invoice.coffee_sum.to_d }
  column(:paid, :money, sort: PAID, priority: 3, &:paid_sum)
  column(:balance, :money, sort: BALANCE) { |invoice| invoice.total_sum.to_d - invoice.coffee_sum.to_d - invoice.paid_sum.to_d }
  column(:payment_status, :badge, sort: "invoices.payment_status") do |invoice|
    [ invoice.human_payment_status, STATUS_TONES.fetch(invoice.payment_status) ]
  end
  column(:payment_method, :text, sort: "invoices.payment_method", priority: 3, &:human_payment_method)
  column(:paid_on, :date, sort: "invoices.paid_on", priority: 3)
  # Days it took to pay, or days it has been waiting.
  column(:days, :integer, sort: "COALESCE(invoices.paid_on, CURRENT_DATE) - invoices.issued_on", priority: 2) do |invoice|
    ((invoice.paid_on || Time.zone.today) - invoice.issued_on).to_i
  end

  measure :count, :integer, "COUNT(*)"
  measure :quintals, :quintals, QUINTALS
  measure :total, :money, "SUM(#{TOTAL})"
  measure :coffee, :money, "SUM(#{COFFEE})"
  measure :to_pay, :money, "SUM(#{TO_PAY})"
  measure :paid, :money, "SUM(#{PAID})"
  measure :pending, :money, "COALESCE(SUM(#{BALANCE}) FILTER (WHERE #{UNPAID}), 0)"
  measure :average_days, :number, "AVG(#{DAYS_TO_PAY})"

  group :week, unit: "week"
  group :month, unit: "month"
  group :producer, sql: "invoices.producer_id", label_sql: "MIN(people.first_names || ' ' || people.last_names)"
  group :payment_status, sql: "invoices.payment_status", translate: ->(status) { Invoice.human_attribute_name("payment_status/#{status}") }
  group :payment_method, sql: "invoices.payment_method", translate: ->(method) {
    method ? Invoice.human_attribute_name("payment_method/#{method}") : I18n.t("reports.types.invoices.no_single_method")
  }

  kpi :count, :integer, "COUNT(*)", good: :up
  kpi :total, :money, "SUM(#{TOTAL})"
  kpi :coffee, :money, "SUM(#{COFFEE})"
  kpi :paid, :money, "SUM(#{PAID})"
  kpi :pending, :money, "COALESCE(SUM(#{BALANCE}) FILTER (WHERE #{UNPAID}), 0)", good: :down
  kpi :pending_count, :integer, "COUNT(*) FILTER (WHERE #{UNPAID})", good: :down
  kpi :average_days, :number, "AVG(#{DAYS_TO_PAY})", good: :down

  def scope
    Invoice.joins(producer: :person).joins(TOTALS)
  end

  def apply_filters(relation)
    if filter.q
      by_person = relation.where(producer_id: Producer.where(person_id: people_matching(filter.q)).select(:id))
      relation = filter.q.match?(/\A\d+\z/) ? by_person.or(relation.where(number: filter.q.to_i)) : by_person
    end
    relation = relation.with_payment_status(filter.payment_status) if filter.payment_status
    # Paid (at least in part) that way.
    relation = relation.where(id: InvoicePayment.where(payment_method: filter.payment_method).select(:invoice_id)) if filter.payment_method
    relation = relation.where(id: Purchase.where(zone_id: filter.zone_id).select(:invoice_id)) if filter.zone_id
    relation
  end

  def charts
    relation = records
    status = human(Invoice, :payment_status)
    labels, by_status = over_time_by(relation, "invoices.payment_status", "SUM(#{TO_PAY})", translate: status)
    # What was paid out, by the method of each payment.
    methods = InvoicePayment.where(invoice_id: plain(relation).select(:id)).group(:payment_method).order(Arel.sql("SUM(amount) DESC"))
                            .sum(:amount).map { |method, amount| [ Invoice.human_attribute_name("payment_method/#{method}"), number(amount) ] }
    pending = plain(relation).where(UNPAID).group(:issued_on).pluck(:issued_on, Arel.sql("SUM(#{BALANCE})"))
    ages = age_buckets(pending.map { |date, amount| [ (today - date).to_i, amount ] }, [ 0, 8, 16, 31, 61 ])
    debtors = breakdown(relation.where(UNPAID), "invoices.producer_id", "SUM(#{BALANCE})",
                        label_sql: "MIN(people.first_names || ' ' || people.last_names)", limit: 10, others: false)
    day_labels, days = over_time(relation.where(payment_status: "paid"), { days: "AVG(#{DAYS_TO_PAY})", count: "COUNT(*)" }, gaps: nil)

    [
      chart(:by_status, :stacked, labels:, datasets: by_status.map { |set| set.merge(format: :money) }, wide: true,
                                  tones: { status.call("pending") => "danger", status.call("partial") => "warning", status.call("paid") => "success" }),
      chart(:pending_age, :bar, labels: ages.map(&:first), datasets: [ dataset(:pending, ages.map(&:last), format: :money) ]),
      chart(:debtors, :hbar, labels: debtors.map(&:first), datasets: [ dataset(:pending, debtors.map(&:last), format: :money) ]),
      chart(:methods, :doughnut, labels: methods.map(&:first), datasets: [ dataset(:paid, methods.map(&:last), format: :money) ]),
      chart(:days_to_pay, :combo, labels: day_labels, datasets: [ dataset(:count, days[:count], format: :integer),
                                                                 dataset(:days, days[:days], format: :number, kind: :line, axis: :y2) ])
    ]
  end

  private
    def preload(relation)
      relation.includes(producer: :person)
              .select("invoices.*", "invoice_totals.purchases_count", "invoice_totals.net_weight AS net_weight_sum",
                      "#{TOTAL} AS total_sum", "#{COFFEE} AS coffee_sum", "#{PAID} AS paid_sum")
    end
end
