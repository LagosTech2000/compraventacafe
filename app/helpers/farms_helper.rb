module FarmsHelper
  # "5 de oct – 11 de oct"
  def format_period(period)
    t("farms.period", from: l(period.starts_on, format: :short), to: l(period.ends_on, format: :short))
  end

  def payroll_kind_badge(payroll)
    tag.span(payroll.human_kind, class: "badge badge-neutral")
  end

  def payroll_status_badge(payroll)
    tag.span(payroll.human_status, class: "badge #{payroll.status == "active" ? "badge-success" : "badge-neutral"}")
  end

  def period_status_badge(row)
    css = { "paid" => "badge-success", "to_pay" => "badge-danger", "in_progress" => "badge-neutral", "upcoming" => "badge-neutral" }.fetch(row.status)
    tag.span(t("farms.period_statuses.#{row.status}"), class: "badge #{css}")
  end

  # What the pay of a line is made of: "5.5 días × L 300.00", "40 latas ×
  # L 25.00" or "2 tareas".
  # basis: "daily", "harvest" or "task" (PayrollPaymentLine#basis).
  def format_work(basis, quantity, rate)
    amount = number_with_precision(quantity, precision: 2, strip_insignificant_zeros: true)
    unit = t("farms.units.#{basis}", count: quantity.to_d == 1 ? 1 : 2)
    rate ? t("farms.work_times_rate", quantity: amount, unit:, rate: format_money(rate)) : "#{amount} #{unit}"
  end

  # The wage a member earns per day and where it comes from.
  def member_wage(member)
    return (member.payroll.harvest? ? t("farms.members.by_cans") : "—") unless member.daily_wage

    source = member.own_wage? ? t("farms.members.own_wage") : member.role&.name
    "#{format_money(member.daily_wage)} · #{source}"
  end
end
