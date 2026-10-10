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
    @active_supplies ||= Supply.active.ordered.to_a
    supplies = @active_supplies
    supplies += [ item.supply ] if item.supply && !item.supply.active?
    supplies.map { |supply| [ supply.name, supply.id ] }
  end

  # "Efectivo", or "Con café · compra 72" for a payment made with a purchase.
  def payment_method_label(payment)
    return payment.human_payment_method unless payment.purchase_id

    t("loans.payments.table.with_purchase", method: payment.human_payment_method, number: payment.purchase_id)
  end

  def loan_kind_badge(loan)
    tag.span(loan.human_kind, class: "badge badge-neutral")
  end

  # "3 sacos", "2.5 galón": the quantity without needless zeros, and the unit.
  def format_quantity(quantity, unit)
    "#{number_with_precision(quantity, precision: 2, strip_insignificant_zeros: true, delimiter: ",")} #{unit}"
  end

  def format_rate(value)
    "#{number_with_precision(value, precision: 2, strip_insignificant_zeros: true)} %"
  end
end
