require "rails_helper"

# Cash and supplies apart (Fernando, 2026-11-12): lent, collected and owed
# of principal in each, a payment split in the loan's proportion; interest
# apart. Each figure opens the loans list filtered (mixed loans in both).
RSpec.describe "Loans: cash and supplies" do
  let(:admin) { create(:user, :admin) }
  let(:supply) { create(:supply, default_price: 100) }

  def page = Nokogiri::HTML(response.body)
  def stat(key) = page.at_css("[data-loans-stat='#{key}']")
  def listed = page.css("tbody tr[id^='loan_']").map { it["id"].delete_prefix("loan_").to_i }

  def loan_with(cash:, supplies:)
    create(:loan, cash_amount: cash, monthly_interest_rate: 0,
                  supply_items_attributes: supplies.positive? ? [ { supply_id: supply.id, quantity: supplies / 100, unit_price: 100 } ] : [])
  end

  let!(:mixed) { loan_with(cash: 6_000, supplies: 4_000) }
  let!(:cash) { loan_with(cash: 1_000, supplies: 0) }
  let!(:supplies) { loan_with(cash: 0, supplies: 500) }

  before { create(:loan_payment, loan: mixed, amount: 5_000, payment_method: "cash") }

  it "splits a payment of a mixed loan as it was lent" do
    balance = mixed.reload.balance
    expect([ balance.cash_paid, balance.supplies_paid ]).to eq([ 3_000, 2_000 ])
    expect([ balance.cash_owed, balance.supplies_owed ]).to eq([ 3_000, 2_000 ])
  end

  it "shows lent, collected and owed in cash and supplies in the summary, each opening the filtered list" do
    sign_in admin
    get loans_root_path
    expect(stat(:lent_cash).at_css("dd").text.strip).to eq("L 7,000.00")
    expect(stat(:lent_supplies).at_css("dd").text.strip).to eq("L 4,500.00")
    expect(stat(:cash_collected).at_css("dd").text.strip).to eq("L 3,000.00")
    expect(stat(:supplies_collected).at_css("dd").text.strip).to eq("L 2,000.00")
    expect(stat(:cash_owed).at_css("dd").text.strip).to eq("L 4,000.00")
    expect(stat(:supplies_owed).at_css("dd").text.strip).to eq("L 2,500.00")
    expect(stat(:supplies_owed)["href"]).to eq(loans_loans_path(status: "unpaid", composition: "with_supplies"))

    get stat(:lent_supplies)["href"]
    expect(listed).to contain_exactly(mixed.id, supplies.id)
    get loans_loans_path(composition: "with_cash")
    expect(listed).to contain_exactly(mixed.id, cash.id)
    split = page.at_css("[data-total='principal'] [data-total-split]").text.squish
    expect(split).to eq("Efectivo L 7,000.00 · Insumos L 4,000.00")
  end

  it "shows the split on a mixed loan, the account and the daily close" do
    sign_in admin
    get loans_loan_path(mixed)
    expect(page.css("[data-principal-split]").map { it.text.squish }).to include("Efectivo L 3,000.00 · insumos L 2,000.00")
    get loans_credit_account_path(mixed.person)
    expect(page.at_css("[data-account-total='lent'] [data-total-split]").text.squish).to eq("Efectivo L 6,000.00 · Insumos L 4,000.00")
    get loans_daily_close_path
    expect(response.body).to include(I18n.t("loans.daily_closes.show.stats.supplies_collected"))
  end
end
