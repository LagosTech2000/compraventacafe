module LoansHelper
  LOAN_STATUS_BADGES = { "active" => "badge-neutral", "overdue" => "badge-danger", "paid_off" => "badge-success" }.freeze
  SCORE_BADGES = { excellent: "badge-success", good: "badge-success", fair: "badge-neutral", risk: "badge-danger", no_history: "badge-neutral" }.freeze

  def loan_status_badge(loan)
    tag.span(loan.human_status, class: "badge #{LOAN_STATUS_BADGES.fetch(loan.status)}")
  end

  # "92 · Excelente", or "Sin historial".
  def payer_score_badge(score)
    label = t("loans.score.categories.#{score.category}")
    text = score.value ? "#{score.value} · #{label}" : label
    tag.span(text, class: "badge #{SCORE_BADGES.fetch(score.category)}", title: t("loans.score.label"))
  end

  # [[name, id], ...] for a supply line: the active supplies, plus the
  # line's own supply if it was deactivated after being lent.
  def supply_options_for(item)
    @active_supplies ||= Supply.active.lendable.ordered.to_a
    supplies = @active_supplies
    supplies += [ item.supply ] if item.supply && !item.supply.active?
    # With what is left to lend (Fernando, 2026-11-12); it may be below zero:
    # what is lent without stock is owed (Fernando, 2026-11-13).
    supplies.map do |supply|
      stock = number_with_precision(supply_available.fetch(supply.id, 0), precision: 2, delimiter: ",", strip_insignificant_zeros: true)
      [ t("loans.loans.form.supply_option", name: supply.name, stock:, unit: supply.unit), supply.id ]
    end
  end

  # { supply id => what is left to lend }: it may be below zero.
  def supply_available
    @supply_available ||= SupplyStock.new.rows.to_h { [ it.supply.id, it.available ] }
  end

  # The supplies the loan form uses, each with what is left to lend, which
  # warns a line that lends more than there is (Fernando, 2026-11-13).
  def loan_supplies_data
    Supply.ordered.to_h { |supply| [ supply.id, supply.picker_data.merge(available: supply_available.fetch(supply.id, 0).to_f) ] }
  end

  # "Efectivo", "Con café · compra 72" for a payment made with a purchase, or
  # "Descuento de planilla · Corte 2026" for one taken from a payroll.
  def payment_method_label(payment)
    if payment.purchase_id
      t("loans.payments.table.with_purchase", method: payment.human_payment_method, number: payment.purchase_id)
    elsif payment.payroll_payment_line
      t("loans.payments.table.with_payroll", method: payment.human_payment_method,
                                             payroll: payment.payroll_payment_line.payment.payroll.name)
    else
      payment.human_payment_method
    end
  end

  def loan_kind_badge(loan)
    tag.span(loan.human_kind, class: "badge badge-neutral")
  end

  # "3 sacos", "2.5 galón": the quantity without needless zeros, and the unit.
  def format_quantity(quantity, unit)
    "#{number_with_precision(quantity, precision: 2, strip_insignificant_zeros: true, delimiter: ",")} #{unit}"
  end

  # [["Temporada 2026-2027", 2026], ...]: the seasons that have loans, the
  # newest first (Season of each loan's date).
  # An amount of principal; on a mixed loan, also its cash and supplies
  # parts (in the loan's proportion, Fernando, 2026-11-12).
  def loan_principal_split(loan, total, cash, supplies)
    return format_money(total) unless loan.cash_amount.to_d.positive? && loan.supplies_value.positive?

    safe_join([ format_money(total), tag.span(t("loans.loans.show.split", cash: format_money(cash), supplies: format_money(supplies)),
                                              class: "block text-xs text-ink-muted", data: { principal_split: true }) ])
  end

  # The loans list's statuses: each loan's, plus «Por cobrar» (active and overdue).
  def loan_filter_status_options
    enum_options(Loan, :status, Loan::STATUSES) + [ [ t("loans.loans.index.unpaid"), "unpaid" ] ]
  end

  # With cash (cash only or mixed) or with supplies (supplies only or mixed).
  def loan_filter_composition_options
    LoanFilter::COMPOSITIONS.map { [ t("loans.loans.index.compositions.#{it}"), it ] }
  end

  # Zones to filter the loans by their person's, and «Sin zona».
  def loan_filter_zone_options
    Zone.ordered.pluck(:name, :id).map { |name, id| [ name, id.to_s ] } + [ [ t("loans.loans.index.no_zone"), LoanFilter::NO_ZONE ] ]
  end

  # How each active filter of the loans list reads (its chips, and the
  # printout's header).
  def loan_filter_labels
    { status: loan_filter_status_options, kind: enum_options(Loan, :kind, Loan::KINDS), composition: loan_filter_composition_options,
      zone_id: ->(value) { (option = loan_filter_zone_options.find { it.last == value }) && t("loans.loans.index.chips.zone", name: option.first) },
      season_year: ->(year) { t("loans.loans.index.chips.season", season: Season.new(year).label) },
      due_from: ->(date) { t("loans.loans.index.chips.due_from", date: l(date)) },
      due_to: ->(date) { t("loans.loans.index.chips.due_to", date: l(date)) } }
  end

  # The active filters in words, for the printout.
  def loan_filter_summary(filter)
    labels = loan_filter_labels.transform_values do |label|
      label.is_a?(Array) ? ->(value) { label.find { |_, option| option.to_s == value.to_s }&.first } : label
    end
    filter_chips(filter, q: ->(text) { t("shared.filters.chips.q", text:) }, **labels).map(&:first)
  end

  def loan_season_options
    first, last = Loan.pick(Arel.sql("MIN(disbursed_on)"), Arel.sql("MAX(disbursed_on)"))
    return [] unless first

    [ Season.current.year, Season.for(last).year ].max.downto(Season.for(first).year).map { [ t("loans.loans.index.season_option", season: Season.new(it).label), it ] }
  end

  # A bucket of the collection calendar: "Vencidos", "Esta semana",
  # "Semana del 9 nov" or "Más adelante"; long: with its dates.
  def calendar_bucket_label(bucket, long: false)
    case bucket.key
    when "late" then t("loans.collection_calendars.show.late")
    when "later" then long ? t("loans.collection_calendars.show.later_long", date: l(bucket.starts_on)) : t("loans.collection_calendars.show.later")
    else
      monday = Date.iso8601(bucket.key)
      label = monday == Time.zone.today.beginning_of_week ? t("loans.collection_calendars.show.this_week") : t("loans.collection_calendars.show.week_of", date: l(monday, format: :short))
      long ? t("loans.collection_calendars.show.week_long", label:, from: l(bucket.starts_on), to: l(bucket.ends_on)) : label
    end
  end

  PORTFOLIO_COLORS = { "current" => "bg-success", "due_soon" => "bg-accent", "late_30" => "bg-warning",
                       "late_60" => "bg-danger/70", "late_90" => "bg-danger/85", "late_more" => "bg-danger" }.freeze

  # The color of a tramo of the portfolio (LoanAging), from on time to very late.
  def portfolio_bucket_color(key) = PORTFOLIO_COLORS.fetch(key)

  # "en 5 días", "hoy", "hace 3 días" from the due date of a loan.
  def due_distance(loan, today = Time.zone.today)
    days = (loan.due_on - today).to_i
    if days.zero? then t("loans.due_distance.today")
    elsif days.positive? then t("loans.due_distance.ahead", count: days)
    else t("loans.due_distance.late", count: -days)
    end
  end

  def format_rate(value)
    "#{number_with_precision(value, precision: 2, strip_insignificant_zeros: true)} %"
  end
end
