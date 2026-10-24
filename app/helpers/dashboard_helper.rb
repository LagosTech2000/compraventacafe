# Texts of the home page (Dashboard).
module DashboardHelper
  # When something happened, on a card of who is connected: the hour if it
  # was today, else the day too ("15 de oct 17:42").
  def presence_time(time)
    time = time.in_time_zone
    l(time, format: time.to_date == Time.zone.today ? :hour : :short)
  end

  # The line under a recent record: its number and amount, as it has them.
  def activity_detail(item)
    detail = item.detail
    case item.kind
    when :purchase then t("dashboard.show.activity.details.purchase", number: detail[:number], quintals: format_pounds(detail[:quintals]), total: format_money(detail[:total]))
    when :producer then detail[:kind]
    when :invoice then t("dashboard.show.activity.details.invoice", number: detail[:number], status: detail[:status], total: format_money(detail[:total]))
    when :shipment then t("dashboard.show.activity.details.shipment", number: detail[:number], pounds: format_pounds(detail[:pounds]))
    when :sale then t("dashboard.show.activity.details.sale", number: detail[:number], status: detail[:status], total: format_money(detail[:total]))
    when :loan then t("dashboard.show.activity.details.loan", number: detail[:number], amount: format_money(detail[:amount]))
    when :loan_payment then t("dashboard.show.activity.details.loan_payment", number: detail[:number], amount: format_money(detail[:amount]))
    when :payroll_payment then t("dashboard.show.activity.details.payroll_payment", farm: detail[:farm], amount: format_money(detail[:amount]))
    end
  end

  # A small line of the closes of the last weeks (CoffeeMarket), drawn on a
  # 100 × 32 box. Decorative: the figures beside it carry the meaning.
  def sparkline(values, css: "h-10 w-full")
    return if values.size < 2

    low, high = values.minmax
    span = (high - low).nonzero? || 1
    points = values.each_with_index.map do |value, index|
      x = (index * 100.0 / (values.size - 1)).round(2)
      y = (30 - (value - low) / span * 28).to_f.round(2)
      "#{x},#{y}"
    end
    tag.svg(tag.polyline(points: points.join(" "), fill: "none", stroke: "currentColor", "stroke-width": 1.5,
                         "vector-effect": "non-scaling-stroke", "stroke-linejoin": "round"),
            viewBox: "0 0 100 32", preserveAspectRatio: "none", class: css, "aria-hidden": true)
  end

  # How many rows each tab of the pending work lists (PendingWorkController).
  def pending_work_count(dashboard, key)
    case key
    when :uninvoiced then dashboard.uninvoiced_by_producer.size
    when :unpaid_invoices then dashboard.unpaid_invoices.size
    when :shipments_in_transit then dashboard.shipments_in_transit.size
    when :unsold_shipments then dashboard.unsold_shipments.size
    when :unpaid_sales then dashboard.unpaid_sales.size
    when :overdue_loans then dashboard.overdue_loans.size
    when :periods_to_pay then dashboard.periods_to_pay.size
    when :members_without_wage then dashboard.members_without_wage.size
    end
  end
end
