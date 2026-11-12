require "rails_helper"

# Inventario de insumos (Fernando, 2026-11-12): an entry adds to the stock
# and registers its investment; loans since the start take from it and
# never take more than there is; the loans before do not count.
RSpec.describe "Supplies' inventory" do
  let(:admin) { create(:user, :admin) }
  let(:supply) { create(:supply, name: "Urea", unit: "saco") }
  let(:category) { create(:finance_category, kind: "investment", name: "Insumos") }
  let(:account) { create(:money_account, opening_balance: 50_000) }
  let(:person) { create(:person) }

  def page = Nokogiri::HTML(response.body)
  def stock = SupplyStock.new.for(supply).stock

  def lend(quantity, on: Time.zone.today)
    post loans_loans_path, params: { loan: { person_id: person.id, cash_amount: "0", monthly_interest_rate: "0", disbursed_on: on, due_on: on + 30,
                                             supply_items_attributes: { "1" => { supply_id: supply.id, quantity: quantity.to_s, unit_price: "900", _destroy: "0" } } } }
  end

  before { sign_in admin }

  it "registers an entry with its investment, and lends only what there is" do
    post sales_supply_entries_path, params: { supply_entry: { supply_id: supply.id, quantity: "20", amount: "16000", received_on: Time.zone.today,
                                                              payee: "Agroservicio El Paraíso", finance_category_id: category.id,
                                                              money_account_id: account.id, payment_method: "cash" } }
    entry = SupplyEntry.last
    expect(entry.expense).to have_attributes(kind: "investment", amount: 16_000, category:, money_account: account, payee: "Agroservicio El Paraíso")
    expect(entry.expense.description).to eq("Compra de insumos: Urea × 20 saco")
    expect(AccountBalance.new.for(account)).to eq(34_000)
    expect(stock).to eq(20)

    lend(15)
    expect(Loan.count).to eq(1)
    expect(stock).to eq(5)

    lend(6)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("No hay suficiente «Urea»", "quedan 5 saco")
    expect(Loan.count).to eq(1)

    get sales_supply_stock_path
    expect(page.at_css("tr#stock_supply_#{supply.id} [data-stock]").text.strip).to eq("5 saco")
  end

  it "does not count the loans before the inventory started" do
    lend(3, on: SupplyStock.starts_on - 1)
    expect(Loan.count).to eq(1)
    expect(stock).to eq(0)
  end

  it "removes an entry with its investment, unless the loans took it" do
    entry = create(:supply_entry, supply:, quantity: 10)
    investment = entry.expense
    lend(4)
    delete sales_supply_entry_path(entry)
    expect(SupplyEntry.exists?(entry.id)).to be(true)
    expect(flash[:alert]).to include("los préstamos ya tomaron")

    Loan.last.destroy!
    delete sales_supply_entry_path(entry)
    expect(SupplyEntry.exists?(entry.id)).to be(false)
    expect(Expense.exists?(investment.id)).to be(false)
  end

  it "keeps its investment from being edited or removed in Control financiero" do
    entry = create(:supply_entry, supply:)
    expect(ExpensePolicy.new(admin, entry.expense)).to forbid_actions(%i[update destroy])
  end

  it "is a tab of its own: only who sees it" do
    user = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "stock", can_read: true) }
    sign_in user
    get sales_supply_stock_path
    expect(response).to redirect_to(root_path)
  end
end
