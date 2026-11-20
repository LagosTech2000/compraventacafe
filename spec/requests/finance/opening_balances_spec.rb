require "rails_helper"

# «Saldos de apertura» (Fernando, 2026-11-18): the accounts were negative
# without their opening balance; the screen says how low each one goes and
# takes the real one.
RSpec.describe "Opening balances" do
  let(:admin) { create(:user, :admin) }
  let(:account) { create(:money_account, name: "Caja", opening_balance: 0, opening_on: 10.days.ago.to_date) }

  def page = Nokogiri::HTML(response.body)

  before do
    create(:expense, money_account: account, amount: 300, spent_on: 5.days.ago.to_date)
    create(:other_income, money_account: account, amount: 100, received_on: 3.days.ago.to_date)
    create(:expense, money_account: account, amount: 50, spent_on: 1.day.ago.to_date)
    sign_in admin
  end

  it "says the lowest balance and the least opening balance, and saves the real one" do
    row = OpeningBalanceCheck.new.rows.find { it.account == account }
    expect(row).to have_attributes(lowest: -300, lowest_on: 5.days.ago.to_date, negative_on: 5.days.ago.to_date, balance: -250, suggested_minimum: 300)

    get finance_money_accounts_path
    expect(page.css("a").map(&:text)).to include("Saldos de apertura")
    get finance_opening_balances_path
    section = page.at_css("##{ActionView::RecordIdentifier.dom_id(account, :opening)}")
    expect(section.at_css("[data-opening-lowest]").text).to include("-L 300.00")
    expect(section.at_css("[data-opening-suggestion]").text).to include("al menos L 300.00")
    expect(page.at_css("[data-opening-negative]").text).to include("Una cuenta")

    patch finance_opening_balance_path(account), params: { money_account: { opening_on: 10.days.ago.to_date, opening_balance: "1000" } }
    expect(response).to redirect_to(finance_opening_balances_path(anchor: ActionView::RecordIdentifier.dom_id(account, :opening)))
    expect(AccountBalance.new.for(account.reload)).to eq(750)
    expect(OpeningBalanceCheck.new.negative).to be_empty
  end

  it "says when there are movements before the opening date, and refuses a bad one" do
    account.update!(opening_on: 4.days.ago.to_date)
    get finance_opening_balances_path
    expect(page.at_css("[data-opening-before]").text).to include(I18n.l(5.days.ago.to_date))

    patch finance_opening_balance_path(account), params: { money_account: { opening_on: "", opening_balance: "1" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "is for who edits Cuentas" do
    sign_in create(:user).tap { create(:permission, user: it, module_key: "finance", submodule_key: "accounts", can_read: true) }
    get finance_opening_balances_path
    expect(response).to redirect_to(root_path)
    patch finance_opening_balance_path(account), params: { money_account: { opening_balance: "1" } }
    expect(account.reload.opening_balance).to eq(0)
  end
end
