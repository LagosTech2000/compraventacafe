require "rails_helper"

# Préstamos → Resumen (Fernando, 2026-11-12): the interest and the principal
# collected of all time, and every figure opens the screen with its detail.
RSpec.describe "Loans summary" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)
  def stat(key) = page.at_css("[data-loans-stat='#{key}']")

  before do
    loan = create(:loan, cash_amount: 1_000, monthly_interest_rate: 3, disbursed_on: Time.zone.today - 30, due_on: Time.zone.today + 30)
    create(:loan_payment, loan:, amount: 130, paid_on: Time.zone.today, payment_method: "cash") # L 30 of interest, L 100 of principal
    create(:loan, cash_amount: 500, monthly_interest_rate: 0, disbursed_on: Time.zone.today - 60, due_on: Time.zone.today - 1)
  end

  it "shows the interest and principal collected, and each figure opens its detail" do
    sign_in admin
    get loans_root_path

    expect(stat(:interest_collected).at_css("dd").text.strip).to eq("L 30.00")
    expect(stat(:principal_collected).at_css("dd").text.strip).to eq("L 100.00")
    expect(stat(:interest_collected)["href"]).to eq(reports_report_path("loan_payments", period: "all"))
    expect(stat(:open_loans)["href"]).to eq(loans_loans_path(status: "unpaid"))
    expect(stat(:overdue_loans)["href"]).to eq(loans_loans_path(status: "overdue"))
  end

  it "shows the collected figures without a link to who does not see Reportería", :all_records do
    user = create(:user).tap { create(:permission, user: it, module_key: "loans", can_read: true) }
    sign_in user
    get loans_root_path
    expect(stat(:interest_collected).name).to eq("div")
    expect(stat(:interest_collected).at_css("dd").text.strip).to eq("L 30.00")
    expect(stat(:open_loans).name).to eq("a")
  end

  it "the loans list and the daily close show the principal and interest collected" do
    sign_in admin
    get loans_loans_path(status: "unpaid")
    expect(page.at_css("[data-total='principal_paid'] dd").text.strip).to eq("L 100.00")
    expect(page.at_css("[data-total='interest_paid'] dd").text.strip).to eq("L 30.00")
    get loans_daily_close_path
    expect(response.body).to include(I18n.t("loans.daily_closes.show.stats.principal_collected"))
  end
end
