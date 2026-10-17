module FarmsHelper
  AREA_PRECISION = { "manzana" => 2, "hectare" => 2, "square_meter" => 0 }.freeze

  # "10.5 mz": an area in one unit (FarmArea::UNITS).
  def format_area(value, unit)
    number = number_with_precision(value, precision: AREA_PRECISION.fetch(unit), delimiter: ",", strip_insignificant_zeros: true)
    t("farms.area.short.#{unit}", value: number)
  end

  # "10.5 mz · 7.34 ha · 73,384 m²", the unit it was written in first; "—" without one.
  def format_farm_area(farm)
    area = farm.area
    return "—" unless area

    [ area.unit, *(FarmArea::UNITS - [ area.unit ]) ].map { |unit| format_area(area.in(unit), unit) }.join(" · ")
  end

  # "5 de oct – 11 de oct"
  # How a task priced by quantity got its value ("10 barriles de 200 L ×
  # L 100.00"); nil for a fixed amount.
  def task_quantity_label(task)
    return if task.fixed? || task.quantity.nil?

    key = task.per_fertilizer? ? "per_fertilizer_#{task.quantity_unit}" : task.pricing
    t("farms.payrolls.tasks.quantity.#{key}", quantity: number_with_precision(task.quantity, precision: 2, strip_insignificant_zeros: true),
                                               liters: number_with_precision(task.barrel_liters, precision: 2, strip_insignificant_zeros: true),
                                               price: format_money(task.unit_price))
  end

  def format_period(period)
    t("farms.period", from: l(period.starts_on, format: :short), to: l(period.ends_on, format: :short))
  end

  def payroll_kind_badge(payroll)
    tag.span(payroll.human_kind, class: "badge badge-neutral")
  end

  def payroll_status_badge(payroll)
    tag.span(payroll.human_status, class: "badge #{payroll.status == "active" ? "badge-success" : "badge-neutral"}")
  end

  # Filter choices: "Activas y por iniciar" (the default), then each status.
  def payroll_status_options
    [ [ t("farms.payrolls.index.unfinished"), "unfinished" ] ] + enum_options(Payroll, :status, Payroll::STATUSES)
  end

  def period_status_badge(row)
    css = { "paid" => "badge-success", "to_pay" => "badge-danger", "in_progress" => "badge-neutral", "upcoming" => "badge-neutral" }.fetch(row.status)
    tag.span(t("farms.period_statuses.#{row.status}"), class: "badge #{css}")
  end

  # The overtime of a line paid by day: "+ 3 h extra × L 50.00 · + 1 día extra";
  # nil without any (PayrollCalculation::Line or PayrollPaymentLine).
  def format_overtime(line)
    return unless line.overtime?

    number = ->(value) { number_with_precision(value, precision: 2, strip_insignificant_zeros: true) }
    parts = []
    if line.overtime_hours.to_d.positive?
      parts << t("farms.overtime.hours", hours: number.(line.overtime_hours), rate: format_money(line.overtime_hour_rate))
    end
    parts << t("farms.overtime.extra_days", count: line.extra_days.to_d == 1 ? 1 : 2, days: number.(line.extra_days)) if line.extra_days.to_d.positive?
    parts.join(" · ")
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
