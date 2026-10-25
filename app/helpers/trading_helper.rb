module TradingHelper
  def format_pounds(value)
    number_with_precision(value, precision: 2, delimiter: ",")
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

  # How a purchase's carrero commission was calculated: "L 0.30 por libra
  # neta", or, before 2026-10-24, "12.50 latas × L 50.00 × 10 %".
  def hauler_terms(purchase)
    if purchase.hauler_price_per_pound
      t("trading.haulers.terms_per_pound", price: format_price_per_pound(purchase.hauler_price_per_pound))
    elsif purchase.hauler_can_price
      t("trading.haulers.terms_by_cans", cans: format_cans(purchase.hauler_cans), price: format_money(purchase.hauler_can_price),
                                         percent: format_percent(purchase.hauler_commission_percent))
    end
  end

  # "100.25": cans of a hauler's commission (Hauler::CAN_POUNDS).
  def format_cans(value)
    number_with_precision(value, precision: 2, delimiter: ",") if value
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

  PAYMENT_STATUS_BADGES = { "paid" => "badge-success", "partial" => "badge-warning", "pending" => "badge-danger" }.freeze
  # A purchase's payment state (PurchaseSummary::PAYMENT_STATES): its invoice's, or not invoiced.
  DAILY_CLOSE_BADGES = PAYMENT_STATUS_BADGES.merge("uninvoiced" => "badge-neutral").freeze

  def payment_status_badge(invoice)
    tag.span(invoice.human_payment_status, class: "badge #{PAYMENT_STATUS_BADGES.fetch(invoice.payment_status)}")
  end
end
