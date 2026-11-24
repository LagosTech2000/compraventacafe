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

  # Pendientes on the left in a vertical card (Fernando, 2026-11-22).
  it "lists the overdue, the due soon, the supplies to deliver and who can pay with coffee" do
    soon = create(:loan, cash_amount: 300, disbursed_on: Time.zone.today - 10, due_on: Time.zone.today + 3)
    supply = create(:supply, name: "Urea", unit: "saco")
    lent = create(:loan, cash_amount: 0, disbursed_on: Time.zone.today, due_on: Time.zone.today + 60,
                         supply_items_attributes: [ { supply_id: supply.id, quantity: 2, unit_price: 100 } ])
    producer = create(:producer, person: soon.person)
    create(:purchase, producer:, gross_weight: 500, price_per_pound: 10)

    sign_in admin
    get loans_root_path
    section = ->(key) { page.at_css("[data-loans-pending] [data-pending-section='#{key}']") }
    expect(section.(:overdue).at_css(".badge").text.strip).to eq("1")
    expect(section.(:due_soon).text).to include(soon.person.full_name, "vence")
    expect(section.(:to_deliver).text).to include(lent.person.full_name, "2 saco de Urea")
    expect(section.(:coffee).text).to include(soon.person.full_name, "Café:")
    expect(section.(:coffee).at_css("a[href='#{loans_coffee_collection_path}']")).to be_present
    expect(page.at_css("[data-loans-stat='open_loans']")["class"]).to include("stat-compact")
  end

  it "leaves out «Con café para abonar» for who does not see Cobrar con café", :all_records do
    user = create(:user).tap { create(:permission, user: it, module_key: "loans", can_read: true) }
    sign_in user
    get loans_root_path
    expect(page.at_css("[data-pending-section='overdue']")).to be_present
    expect(page.at_css("[data-pending-section='coffee']")).to be_nil
  end

  # The loans' money instead of a loans' account, and an ⓘ on every figure (Fernando, 2026-11-23).
  it "shows the loans' money and explains every figure" do
    box = create(:money_account, name: "Caja", default_for: %w[cash])
    loan = create(:loan, cash_amount: 2_000, monthly_interest_rate: 0, disbursed_on: Time.zone.today - 5, due_on: Time.zone.today + 30, money_account: box)
    create(:loan_payment, loan:, amount: 300, paid_on: Time.zone.today, payment_method: "cash", money_account: box)
    sign_in admin
    get loans_root_path
    expect(stat(:cash_out).at_css("dd").text.strip).to eq("L 2,000.00")
    expect(stat(:money_in).at_css("dd").text.strip).to eq("L 430.00")
    expect(stat(:net).at_css("dd").text.strip).to eq("−L 1,570.00").or eq("-L 1,570.00")
    tips = page.css(".info-tip [role=tooltip]")
    expect(tips.size).to eq(page.css("[data-loans-stat]").size)
    expect(tips.map(&:text)).to all(be_present)
  end
end
