# The coffee's kardex in a period (Comercialización): every purchase that
# came in (its net) and every truck that left (its net on the local scale),
# by coffee state, with the stock before, after and in between. Voided ones
# are left out, as in the stock. Purchases and shipments are put together
# in Ruby (InMemoryReport).
class CoffeeStockReport < Report
  include InMemoryReport

  KINDS = %w[purchase shipment].freeze

  Entry = Data.define(:id, :date, :at, :kind, :description, :coffee_state, :pounds_in, :pounds_out, :route) do
    def net = pounds_in - pounds_out
    def quintals = PurchaseCalculation.quintals(net)
  end

  self.module_key = "sales"
  self.date_column = "date"
  self.default_period = "this_month"
  self.default_sort = :at
  self.default_measure = :net

  filter :coffee_state, :choice, in: Purchase::COFFEE_STATES
  filter :kind, :choice, in: KINDS

  detail { |entry| entry.route && (entry.kind == "shipment" || policy(Purchase).show?) ? public_send(*entry.route) : nil }

  column(:at, :datetime, sort: :at)
  column(:kind, :text, sort: :kind) { |entry| I18n.t("reports.types.coffee_stock.kinds.#{entry.kind}") }
  column(:description, :text, sort: :description, &:description)
  column(:coffee_state, :text, sort: :coffee_state, priority: 2) { |entry| Purchase.human_attribute_name("coffee_state/#{entry.coffee_state}") }
  column(:pounds_in, :pounds, sort: :pounds_in) { |entry| entry.pounds_in if entry.pounds_in.positive? }
  column(:pounds_out, :pounds, sort: :pounds_out) { |entry| entry.pounds_out if entry.pounds_out.positive? }

  measure :count, :integer, nil
  measure :pounds_in, :pounds, nil
  measure :pounds_out, :pounds, nil
  measure :net, :pounds, nil

  group :day, unit: "day"
  group :week, unit: "week"
  group :month, unit: "month"
  group :coffee_state, translate: ->(state) { Purchase.human_attribute_name("coffee_state/#{state}") }
  group :kind, translate: ->(kind) { I18n.t("reports.types.coffee_stock.kinds.#{kind}") }

  kpi(:pounds_in, :pounds, good: :up) { |entries, _| entries.sum(0.to_d, &:pounds_in) }
  kpi(:pounds_out, :pounds, good: :up) { |entries, _| entries.sum(0.to_d, &:pounds_out) }
  kpi(:net, :pounds) { |entries, _| entries.sum(0.to_d, &:net) }
  # What there was before and after the period (end of its last day).
  kpi(:opening, :pounds, compare: false) { |_, in_period| stock_at(in_period.range&.begin&.yesterday) }
  kpi(:closing, :pounds, compare: false) { |_, in_period| stock_at(in_period.range&.end || today) }

  def apply_filters(entries)
    entries = entries.select { |entry| entry.coffee_state == filter.coffee_state } if filter.coffee_state
    entries = entries.select { |entry| entry.kind == filter.kind } if filter.kind
    entries
  end

  def charts
    entries = records
    unit = bucket_unit
    dates = buckets(unit, entries.map { |entry| bucket(entry.date, unit) }.uniq)
    by_bucket = entries.group_by { |entry| bucket(entry.date, unit) }
    ins = dates.map { |date| number(by_bucket.fetch(date, []).sum(0, &:pounds_in)) }
    outs = dates.map { |date| number(by_bucket.fetch(date, []).sum(0, &:pounds_out)) }
    running = stock_at(dates.first&.yesterday).to_d
    balance = ins.zip(outs).map { |pounds_in, pounds_out| number(running += pounds_in - pounds_out) }
    stock = CoffeeStock.new(period.range&.end || today).rows.select { |row| filter.coffee_state.nil? || row.coffee_state == filter.coffee_state }

    [
      chart(:flow, :combo, labels: dates.map { |date| bucket_label(date, unit) },
                           datasets: [ dataset(:pounds_in, ins, format: :pounds), dataset(:pounds_out, outs, format: :pounds),
                                       dataset(:stock, balance, format: :pounds, kind: :line, axis: :y2) ], wide: true,
                           tones: { I18n.t("reports.types.coffee_stock.series.pounds_in") => "success",
                                    I18n.t("reports.types.coffee_stock.series.pounds_out") => "danger" }),
      chart(:by_state, :doughnut, labels: stock.map(&:human_coffee_state), datasets: [ dataset(:stock, stock.map { number([ it.stock, 0 ].max) }, format: :pounds) ])
    ]
  end

  private
    # Net pounds in stock at the end of a day (of the chosen coffee state).
    def stock_at(date)
      return 0.to_d unless date

      CoffeeStock.new(date).rows.select { |row| filter.coffee_state.nil? || row.coffee_state == filter.coffee_state }.sum(&:stock)
    end

    def load(in_period)
      purchases(in_period) + shipments(in_period)
    end

    def purchases(in_period)
      within(Purchase.active.joins(producer: :person), in_period, column: "purchases.purchased_at", type: :datetime)
        .pluck("purchases.id", "purchases.purchased_at", "purchases.coffee_state", "purchases.net_weight",
               Arel.sql("people.first_names || ' ' || people.last_names"))
        .map do |id, at, state, net, name|
          Entry.new(id:, date: at.in_time_zone.to_date, at:, kind: "purchase", description: I18n.t("reports.types.coffee_stock.purchase", number: id, name:),
                    coffee_state: state, pounds_in: net.to_d, pounds_out: 0.to_d, route: [ :trading_purchase_path, id ])
        end
    end

    def shipments(in_period)
      within(Shipment.active.joins(:buyer), in_period, column: "shipments.departed_at", type: :datetime)
        .pluck("shipments.id", "shipments.number", "shipments.departed_at", "shipments.coffee_state", "shipments.origin_net_weight", "buyers.name")
        .map do |id, number, at, state, net, name|
          Entry.new(id:, date: at.in_time_zone.to_date, at:, kind: "shipment",
                    description: I18n.t("reports.types.coffee_stock.shipment", number: format("%04d", number), name:),
                    coffee_state: state, pounds_in: 0.to_d, pounds_out: net.to_d, route: [ :sales_shipment_path, id ])
        end
    end
end
