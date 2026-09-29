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

  def format_rate(value)
    "#{number_with_precision(value, precision: 2, strip_insignificant_zeros: true)} %"
  end
end
