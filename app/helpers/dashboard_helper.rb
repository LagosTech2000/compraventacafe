# Texts of the home page (Dashboard).
module DashboardHelper
  # The line under a recent record: its number and amount, as it has them.
  def activity_detail(item)
    detail = item.detail
    case item.kind
    when :purchase then t("dashboard.show.activity.details.purchase", number: detail[:number], quintals: format_pounds(detail[:quintals]), total: format_money(detail[:total]))
    when :producer then detail[:kind]
    when :invoice then t("dashboard.show.activity.details.invoice", number: detail[:number], status: detail[:status], total: format_money(detail[:total]))
    when :loan then t("dashboard.show.activity.details.loan", number: detail[:number], amount: format_money(detail[:amount]))
    when :loan_payment then t("dashboard.show.activity.details.loan_payment", number: detail[:number], amount: format_money(detail[:amount]))
    when :payroll_payment then t("dashboard.show.activity.details.payroll_payment", farm: detail[:farm], amount: format_money(detail[:amount]))
    end
  end
end
