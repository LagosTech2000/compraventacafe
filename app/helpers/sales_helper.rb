module SalesHelper
  SHIPMENT_STATUS_BADGES = { "in_transit" => "badge-warning", "received" => "badge-neutral", "sold" => "badge-success", "voided" => "badge-neutral" }.freeze
  SALE_STATE_BADGES = TradingHelper::PAYMENT_STATUS_BADGES.merge("voided" => "badge-neutral").freeze

  def shipment_status_badge(shipment)
    tag.span(shipment.human_status, class: "badge #{SHIPMENT_STATUS_BADGES.fetch(shipment.status)}")
  end

  def sale_state_badge(sale)
    label = sale.voided? ? t("sales.sales.voided") : sale.human_payment_status
    tag.span(label, class: "badge #{SALE_STATE_BADGES.fetch(sale.state)}")
  end

  # "−120.50 lb (−1.2 %)": the buyer's scale against the local one. Stands
  # out (with a mark that does not depend on color) over the tolerance.
  def weight_difference(record, pounds: record.net_difference, percent: record.difference_percent)
    return tag.span("—", class: "text-ink-muted") if pounds.nil?

    over = record.over_tolerance?
    text = "#{signed(format_pounds(pounds), pounds)} lb"
    text += " (#{signed(format_percent(percent.abs), percent)})" if percent
    tag.span(class: [ "whitespace-nowrap tabular-nums", over ? "font-semibold text-danger" : nil ], data: { over_tolerance: over }) do
      safe_join([ (icon(:alert, css: "mr-1 inline size-4 align-text-bottom") if over), text,
                  (tag.span(t("sales.difference.over_tolerance"), class: "sr-only") if over) ].compact)
    end
  end

  # Where a kardex entry opens: its purchase (only for who sees Compra de
  # café) or its shipment.
  def ledger_entry_path(entry)
    case entry.kind
    when "purchase" then (trading_purchase_path(entry.record) if policy(Purchase).show?)
    when "shipment" then sales_shipment_path(entry.record)
    when "transfer_in", "transfer_out" then sales_warehouse_transfer_path(entry.record)
    else sales_coffee_conversion_path(entry.record)
    end
  end

  # How a processing cost was charged: "L 0.50 por libra bruta de lo que
  # entró · 1,000.00 lb" or "Monto total".
  def processing_cost_terms(cost)
    return ProcessingCost.human_attribute_name("pricing/total") if cost.total?

    unit = cost.per_quintal? ? t("sales.processing_costs.terms.quintal", pounds: cost.quintal_pounds) : t("sales.processing_costs.terms.pound")
    t("sales.processing_costs.terms.per_unit", price: format_price_per_pound(cost.unit_price), unit:,
      kind: ProcessingCost.human_attribute_name("weight_kind/#{cost.weight_kind}").downcase,
      side: ProcessingCost.human_attribute_name("weight_side/#{cost.weight_side}").downcase, pounds: format_pounds(cost.base_pounds))
  end

  # How long a lot has been in stock: hours for the first two days (cherry
  # counts them), then days.
  def stock_age(lot)
    hours = lot.hours
    hours < 48 ? t("sales.lots.hours", count: hours) : t("sales.lots.days", count: lot.days)
  end

  # "Todas · Bodega 1 · Bodega 2": links to the same page of one warehouse
  # or of all, inside `frame`.
  def warehouse_tabs(warehouses, current, frame:, &path)
    tag.nav(class: "flex flex-wrap gap-2", aria: { label: Warehouse.model_name.human(count: 2) }) do
      safe_join([ nil, *warehouses ].map do |warehouse|
        active = current&.id == warehouse&.id
        link_to(warehouse&.name || t("sales.warehouses.all"), path.call(warehouse&.id),
                class: "btn btn-sm #{"btn-primary" if active}", aria: { current: (active ? "page" : nil) },
                data: { turbo_frame: frame, turbo_action: "advance" })
      end)
    end
  end

  # "+1,000.00" / "−487.06" / "0.00": a kardex move in or out.
  def signed_pounds(value)
    sign = if value.positive? then "+" elsif value.negative? then "−" else "" end
    "#{sign}#{format_pounds(value.abs)}"
  end

  private
    def signed(text, value)
      return text unless value
      return "+#{text}" if value.positive?

      value.negative? && !text.start_with?("-") ? "−#{text}" : text.sub(/\A-/, "−")
    end
end
