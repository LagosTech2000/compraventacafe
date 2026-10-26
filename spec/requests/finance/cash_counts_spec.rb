require "rails_helper"

# Cash counts from an account's page (Fernando, 2026-10-25).
RSpec.describe "Finance cash counts" do
  let(:admin) { create(:user, :admin) }
  let!(:box) { create(:money_account, name: "Caja", opening_balance: 2_000, default_for: %w[cash]) }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "counts the cash box, shows the difference on the account and removes it, audited" do
    get new_finance_cash_count_path(account: box.id)
    expect(response).to have_http_status(:ok)
    expect(page.at_css("select#cash_count_money_account_id option[selected]").text).to eq("Caja")

    post finance_cash_counts_path, params: { cash_count: { money_account_id: box.id, counted_on: Time.zone.today, counted_amount: "1950",
                                                           observations: "Faltan 50" } }
    count = CashCount.sole
    expect(response).to redirect_to(finance_money_account_path(box))
    expect(flash[:notice]).to include("−L 50.00")
    expect(count).to have_attributes(system_balance: 2_000, created_by: admin)
    expect(AuditEvent.where(auditable: count, action: "create")).to exist

    get finance_money_account_path(box)
    expect(page.at_css("[data-cash-count]").text.squish).to include("L 2,000.00", "L 1,950.00", "−L 50.00", admin.name, "Faltan 50")

    delete finance_cash_count_path(count)
    expect(CashCount.count).to eq(0)
  end

  it "keeps the form when the date is in the future" do
    post finance_cash_counts_path, params: { cash_count: { money_account_id: box.id, counted_on: Time.zone.today + 1, counted_amount: "10" } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
