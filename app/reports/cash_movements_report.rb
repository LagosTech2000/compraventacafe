# Money that came in and went out in the period, as the system records it,
# across modules (MoneyMovements: payments to producers, haulers, cash
# lent, payrolls and their expenses, expenses and investments going out;
# loan payments in money, collections of coffee sales and other income
# coming in). Each user sees the sources of the modules they read. Transfers
# between accounts only show for an account: for the business they move
# nothing. Needs the read permission of Compra de café, Préstamos and Fincas.
class CashMovementsReport < Report
  include InMemoryReport

  SOURCES = MoneyMovements::SOURCES
  DIRECTIONS = %w[in out].freeze
  NONE = "none".freeze

  self.module_key = "trading"
  self.date_column = "date"
  self.default_period = "this_month"
  self.default_sort = :date
  self.default_measure = :amount_out

  filter :q, :text
  filter :direction, :choice, in: DIRECTIONS
  filter :source, :choice, in: SOURCES
  # An account's id, or "none" (registered without one).
  filter :account, :text

  def self.module_keys = %w[trading loans farms]

  detail { |movement| movement.route && public_send(*movement.route) }

  column(:date, :date, sort: :date)
  column(:source, :text, sort: :source, priority: 2) { |movement| I18n.t("reports.types.cash_movements.sources.#{movement.source}") }
  column(:description, :text, sort: :description, &:description)
  column(:person, :text, sort: :person, priority: 2, &:person)
  column(:payment_method, :text, sort: :payment_method, priority: 3, &:payment_method)
  column(:account, :text, sort: :account_name, priority: 3) { |movement| movement.account_name || I18n.t("reports.types.cash_movements.no_account") }
  column(:category, :text, sort: :category, priority: 3, &:category)
  column(:amount_in, :money, sort: :amount_in) { |movement| movement.amount_in if movement.amount_in.positive? }
  column(:amount_out, :money, sort: :amount_out) { |movement| movement.amount_out if movement.amount_out.positive? }

  measure :count, :integer, nil
  measure :amount_in, :money, nil
  measure :amount_out, :money, nil
  measure :net, :money, nil

  group :day, unit: "day"
  group :week, unit: "week"
  group :month, unit: "month"
  group :source, translate: ->(source) { I18n.t("reports.types.cash_movements.sources.#{source}") }
  group :direction, translate: ->(direction) { I18n.t("reports.types.cash_movements.directions.#{direction}") }
  group :account_id, translate: ->(id) { MoneyAccount.find_by(id:)&.name || I18n.t("reports.types.cash_movements.no_account") }

  kpi(:amount_in, :money, good: :up) { |movements, _| movements.sum(0.to_d, &:amount_in) }
  kpi(:amount_out, :money, good: :down) { |movements, _| movements.sum(0.to_d, &:amount_out) }
  kpi(:net, :money, good: :up) { |movements, _| movements.sum(0.to_d, &:net) }
  kpi(:count, :integer) { |movements, _| movements.size }

  def apply_filters(movements)
    movements = movements.reject(&:transfer?) unless account_id
    movements = movements.select { |movement| movement.direction == filter.direction } if filter.direction
    movements = movements.select { |movement| movement.source == filter.source } if filter.source
    if filter.q
      text = filter.q.downcase
      movements = movements.select { |movement| [ movement.description, movement.person ].compact.any? { |value| value.downcase.include?(text) } }
    end
    movements
  end

  def charts
    movements = records
    unit = bucket_unit
    dates = buckets(unit, movements.map { |movement| bucket(movement.date, unit) }.uniq)
    by_bucket = movements.group_by { |movement| bucket(movement.date, unit) }
    ins = dates.map { |date| number(by_bucket.fetch(date, []).sum(0, &:amount_in)) }
    outs = dates.map { |date| number(by_bucket.fetch(date, []).sum(0, &:amount_out)) }
    running = 0
    balance = ins.zip(outs).map { |amount_in, amount_out| number(running += amount_in - amount_out) }
    out_sources = sum_by(movements.select { |movement| movement.amount_out.positive? }, :amount_out) do |movement|
      I18n.t("reports.types.cash_movements.sources.#{movement.source}")
    end
    in_methods = sum_by(movements.select { |movement| movement.amount_in.positive? }, :amount_in, &:payment_method)

    [
      chart(:flow, :combo, labels: dates.map { |date| bucket_label(date, unit) },
                           datasets: [ dataset(:amount_in, ins, format: :money), dataset(:amount_out, outs, format: :money),
                                       dataset(:balance, balance, format: :money, kind: :line, axis: :y2) ], wide: true,
                           tones: { I18n.t("reports.series.amount_in") => "success", I18n.t("reports.series.amount_out") => "danger" }),
      chart(:out_sources, :doughnut, labels: out_sources.map(&:first), datasets: [ dataset(:amount_out, out_sources.map(&:last), format: :money) ]),
      chart(:in_methods, :doughnut, labels: in_methods.map(&:first), datasets: [ dataset(:amount_in, in_methods.map(&:last), format: :money) ])
    ]
  end

  private
    def load(in_period)
      range = in_period&.range
      MoneyMovements.new(range: range && (range.begin..range.end), account: account_id, sources: MoneyMovements.sources_for(user)).all
    end

    # The account chosen: its id, :none, or nil.
    def account_id
      return :none if filter.account == NONE

      filter.account.to_s.match?(/\A\d+\z/) ? filter.account.to_i : nil
    end
end
