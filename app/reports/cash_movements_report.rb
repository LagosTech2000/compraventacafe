# Money that came in and went out in the period, as the system records it,
# across modules:
#
#   out  payments to producers on their invoices (each on its date; an
#        invoice paid in parts goes out part by part), payments of the
#        haulers' commissions, cash lent (supplies are not money), payroll
#        payments (what was handed to the members) and payroll expenses
#   in   loan payments in cash, transfer or check (paid with coffee or
#        from a payroll, no money moves)
#
# Coffee sales are not in the system yet, so they are not here. The
# movements come from six tables and are few, so they are put together in
# Ruby. Needs the read permission of the three modules.
class CashMovementsReport < Report
  SOURCES = %w[invoices hauler_payments loans loan_payments payroll_payments payroll_expenses].freeze
  DIRECTIONS = %w[in out].freeze
  NAME = "people.first_names || ' ' || people.last_names".freeze

  Movement = Data.define(:id, :date, :source, :description, :person, :payment_method, :amount_in, :amount_out, :route) do
    def net = amount_in - amount_out
    def direction = amount_in.positive? ? "in" : "out"
  end

  self.module_key = "trading"
  self.date_column = "date"
  self.default_period = "this_month"
  self.default_sort = :date
  self.default_measure = :amount_out

  filter :q, :text
  filter :direction, :choice, in: DIRECTIONS
  filter :source, :choice, in: SOURCES

  def self.module_keys = %w[trading loans farms]

  detail { |movement| movement.route && public_send(*movement.route) }

  column(:date, :date, sort: :date)
  column(:source, :text, sort: :source, priority: 2) { |movement| I18n.t("reports.types.cash_movements.sources.#{movement.source}") }
  column(:description, :text, sort: :description, &:description)
  column(:person, :text, sort: :person, priority: 2, &:person)
  column(:payment_method, :text, sort: :payment_method, priority: 3, &:payment_method)
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

  kpi(:amount_in, :money, good: :up) { |movements, _| movements.sum(0.to_d, &:amount_in) }
  kpi(:amount_out, :money, good: :down) { |movements, _| movements.sum(0.to_d, &:amount_out) }
  kpi(:net, :money, good: :up) { |movements, _| movements.sum(0.to_d, &:net) }
  kpi(:count, :integer) { |movements, _| movements.size }

  def records(in_period = period)
    @records ||= {}
    @records[in_period.range] ||= apply_filters(load(in_period))
  end

  def apply_filters(movements)
    movements = movements.select { |movement| movement.direction == filter.direction } if filter.direction
    movements = movements.select { |movement| movement.source == filter.source } if filter.source
    if filter.q
      text = filter.q.downcase
      movements = movements.select { |movement| [ movement.description, movement.person ].compact.any? { |value| value.downcase.include?(text) } }
    end
    movements
  end

  def total_count = grouped? ? grouped_rows.size : records.size

  def page(number = filter.page)
    rows = grouped? ? grouped_rows : sorted_movements
    from = (number - 1) * PER_PAGE
    [ rows[from, PER_PAGE] || [], rows.size > from + PER_PAGE ]
  end

  def each_row(&) = (grouped? ? grouped_rows : sorted_movements).first(CSV_LIMIT).each(&)

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
    def sorted_movements
      key = sort_key.to_sym
      present, missing = records.partition { |movement| !movement.public_send(key).nil? }
      present = present.sort_by { |movement| [ movement.public_send(key), movement.date, movement.id ] }
      present.reverse! if sort_direction == "desc"
      present + missing
    end

    def grouped_rows
      @grouped_rows ||= begin
        rows = records.group_by { |movement| group_key(movement) }.map do |key, movements|
          values = { "count" => movements.size, "amount_in" => movements.sum(0.to_d, &:amount_in),
                     "amount_out" => movements.sum(0.to_d, &:amount_out), "net" => movements.sum(0.to_d, &:net) }
          GroupRow.new(key, group_label(key, nil), values)
        end
        rows = rows.sort_by { |row| sort_key == "group" ? row.key : row[sort_key] }
        sort_direction == "desc" ? rows.reverse : rows
      end
    end

    def group_key(movement)
      grouping.unit ? bucket(movement.date, grouping.unit) : movement.public_send(grouping.key)
    end

    def bucket(date, unit)
      case unit
      when "week" then date.beginning_of_week
      when "month" then date.beginning_of_month
      else date
      end
    end

    def bucket_unit(_ = nil)
      dates = records.map(&:date)
      days = period.length_in_days || (dates.any? ? (dates.max - dates.min).to_i + 1 : 1)
      if days <= 45 then "day"
      elsif days <= 190 then "week"
      else "month"
      end
    end

    def sum_by(movements, amount, &label)
      movements.group_by(&label).map { |name, list| [ name, number(list.sum(0, &amount)) ] }.sort_by { |_, value| -value }
    end

    def load(in_period)
      invoices(in_period) + hauler_payments(in_period) + loans(in_period) + loan_payments(in_period) + payroll_payments(in_period) + expenses(in_period)
    end

    def movement(id, date, source, description, amount_in: 0, amount_out: 0, person: nil, payment_method: nil, route: nil)
      Movement.new(id:, date:, source:, description:, person:, payment_method:, amount_in: amount_in.to_d, amount_out: amount_out.to_d, route:)
    end

    # Each payment to a producer on its date: an invoice paid in parts goes out part by part.
    def invoices(in_period)
      within(InvoicePayment.joins(invoice: { producer: :person }), in_period, column: "invoice_payments.paid_on")
        .pluck("invoice_payments.id", "invoice_payments.paid_on", "invoices.number", "invoice_payments.payment_method",
               Arel.sql(NAME), "invoice_payments.amount", "invoices.id")
        .map do |id, date, number, method, name, amount, invoice_id|
          movement(id, date, "invoices", I18n.t("reports.types.cash_movements.invoice", number: format("%04d", number)),
                   amount_out: amount, person: name, payment_method: Invoice.human_attribute_name("payment_method/#{method}"),
                   route: [ :trading_invoice_path, invoice_id ])
        end
    end

    def hauler_payments(in_period)
      within(HaulerPayment.joins(hauler: :person), in_period, column: "hauler_payments.paid_on")
        .pluck("hauler_payments.id", "hauler_payments.paid_on", "hauler_payments.payment_method", Arel.sql(NAME),
               "hauler_payments.amount", "hauler_payments.hauler_id")
        .map do |id, date, method, name, amount, hauler_id|
          movement(id, date, "hauler_payments", I18n.t("reports.types.cash_movements.hauler_payment", number: format("%04d", id)),
                   amount_out: amount, person: name, payment_method: Invoice.human_attribute_name("payment_method/#{method}"),
                   route: [ :trading_hauler_payment_path, hauler_id, id ])
        end
    end

    def loans(in_period)
      within(Loan.where("loans.cash_amount > 0").joins(:person), in_period, column: "loans.disbursed_on")
        .pluck(:id, :disbursed_on, :cash_amount, Arel.sql(NAME))
        .map do |id, date, amount, name|
          movement(id, date, "loans", I18n.t("reports.types.cash_movements.loan", number: id), amount_out: amount, person: name,
                                                                                               route: [ :loans_loan_path, id ])
        end
    end

    def loan_payments(in_period)
      within(LoanPayment.where(payment_method: LoanPayment::PAYMENT_METHODS).joins(loan: :person), in_period, column: "loan_payments.paid_on")
        .pluck(:id, :loan_id, :paid_on, :amount, :payment_method, Arel.sql(NAME))
        .map do |id, loan_id, date, amount, method, name|
          movement(id, date, "loan_payments", I18n.t("reports.types.cash_movements.loan_payment", number: format("%04d", id), loan: loan_id),
                   amount_in: amount, person: name, payment_method: LoanPayment.human_attribute_name("payment_method/#{method}"),
                   route: [ :loans_loan_payment_path, loan_id, id ])
        end
    end

    def payroll_payments(in_period)
      within(PayrollPayment.joins(payroll: :farm), in_period, column: "payroll_payments.paid_on")
        .pluck(:id, :payroll_id, :paid_on, :net_total, "payrolls.name", "farms.name", :period_starts_on, :period_ends_on)
        .map do |id, payroll_id, date, amount, payroll, farm, from, to|
          period = I18n.t("farms.period", from: I18n.l(from, format: :short), to: I18n.l(to, format: :short))
          movement(id, date, "payroll_payments", I18n.t("reports.types.cash_movements.payroll_payment", payroll:, farm:, period:),
                   amount_out: amount, route: [ :farms_payroll_payment_path, payroll_id, id ])
        end
    end

    def expenses(in_period)
      within(PayrollExpense.joins(:category, payroll: :farm), in_period, column: "payroll_expenses.spent_on")
        .pluck(:id, :spent_on, :amount, :description, "expense_categories.name", "farms.name")
        .map do |id, date, amount, description, category, farm|
          movement(id, date, "payroll_expenses", I18n.t("reports.types.cash_movements.expense", category:, description:, farm:),
                   amount_out: amount)
        end
    end
end
