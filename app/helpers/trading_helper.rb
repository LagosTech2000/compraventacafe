module TradingHelper
  def format_pounds(value)
    number_with_precision(value, precision: 2, delimiter: ",")
  end

  # Gross pounds first and net beside (Fernando, 2026-11-13: «en toda parte
  # que se muestren las libras netas, mostrar las brutas primero y a la par
  # las netas»): "1,000.00 lb brutas · 487.06 lb netas". Each half stays on
  # one line and the net goes below when both do not fit (Fernando,
  # 2026-11-14: they broke the cards of Salidas); `.gross-net` hides the dot
  # that would start the second line.
  def format_gross_net(gross, net)
    tag.span(class: "gross-net") do
      safe_join([ tag.span(t("shared.pounds.gross", pounds: gross ? format_pounds(gross) : "—")),
                  tag.span(t("shared.pounds.net", pounds: net ? format_pounds(net) : "—")) ])
    end
  end

  def format_money(value)
    number_to_currency(value)
  end

  # "10 %", "2.5 %": a percent without trailing zeros.
  def format_percent(value)
    number_to_percentage(value, precision: 2, strip_insignificant_zeros: true, format: "%n %") if value
  end

  # "L 0.30", "L 0.3025": a price per pound, with up to 4 decimals.
  def format_price_per_pound(value)
    return unless value

    decimals = value.to_d.round(4).to_s("F").split(".").last.sub(/0+\z/, "").length.clamp(2, 4)
    number_to_currency(value, precision: decimals)
  end

  # How a purchase's carrero commission was calculated: "L 0.30 por libra neta".
  def hauler_terms(purchase)
    t("trading.haulers.terms_per_pound", price: format_price_per_pound(purchase.hauler_price_per_pound)) if purchase.hauler_price_per_pound
  end

  # "Temporada 2026-2027"
  def format_season(season)
    t("trading.season.name", season: season.label) if season
  end

  # "Temporada 2026-2027: 1 de septiembre de 2026 al 31 de agosto de 2027"
  def format_season_dates(season)
    t("trading.season.dates", name: format_season(season),
                              from: l(season.starts_on, format: :long), to: l(season.ends_on, format: :long))
  end

  # [[label, year], ...] of the seasons a set of purchases spans (plus the
  # current one, unless include_current is false), newest first.
  def season_options(purchases, include_current: true)
    years = purchases.distinct.pluck(:season_year)
    years |= [ Season.current.year ] if include_current
    years.sort.reverse.map { |year| [ format_season(Season.new(year)), year ] }
  end

  # [[label, value], ...] for a closed list stored as strings.
  def enum_options(model_class, attribute, values)
    values.map { |value| [ model_class.human_attribute_name("#{attribute}/#{value}"), value ] }
  end

  PAYMENT_STATUS_BADGES = { "paid" => "badge-success", "partial" => "badge-warning", "pending" => "badge-danger", "voided" => "badge-neutral" }.freeze
  # A purchase's payment state (PurchaseSummary::PAYMENT_STATES): its invoice's, or not invoiced.
  DAILY_CLOSE_BADGES = PAYMENT_STATUS_BADGES.merge("uninvoiced" => "badge-neutral").freeze

  def payment_status_badge(invoice)
    tag.span(invoice.human_payment_status, class: "badge #{PAYMENT_STATUS_BADGES.fetch(invoice.state)}")
  end
end
