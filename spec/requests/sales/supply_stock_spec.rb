require "rails_helper"

# Insumos (Fernando, 2026-11-12/13): an entry brings one or more supplies
# of an invoice and registers one investment; loans since the start take
# from what is available, even below zero (then they owe it); each loan's
# supply is pending until an administrator marks it delivered, which takes
# it out of the warehouse; the loans before do not count.
RSpec.describe "Supplies' inventory" do
  let(:admin) { create(:user, :admin) }
  let(:supply) { create(:supply, name: "Urea", unit: "saco") }
  let(:fungicide) { create(:supply, name: "Fungicida", unit: "litro") }
  let(:category) { create(:finance_category, kind: "investment", name: "Insumos") }
  let(:account) { create(:money_account, opening_balance: 50_000) }
  let(:person) { create(:person, first_names: "Rosa", last_names: "Mejía") }

  def page = Nokogiri::HTML(response.body)
  def row(of = supply) = SupplyStock.new.for(of)

  def lend(quantity, on: Time.zone.today)
    post loans_loans_path, params: { loan: { person_id: person.id, cash_amount: "0", monthly_interest_rate: "0", disbursed_on: on, due_on: on + 30,
                                             supply_items_attributes: { "1" => { supply_id: supply.id, quantity: quantity.to_s, unit_price: "900", _destroy: "0" } } } }
    Loan.last
  end

  def receipt = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 factura"), "application/pdf", original_filename: "factura.pdf")

  before { sign_in admin }

  it "registers an entry with several supplies and its invoice, as one investment" do
    post sales_supply_entries_path, params: { supply_entry: {
      received_on: Time.zone.today, payee: "Agroservicio El Paraíso", finance_category_id: category.id,
      money_account_id: account.id, payment_method: "cash", receipt_upload: receipt,
      lines_attributes: { "0" => { supply_id: supply.id, quantity: "20", amount: "16000" },
                          "1" => { supply_id: fungicide.id, quantity: "5", amount: "1500" } }
    } }
    entry = SupplyEntry.last
    expect(entry.lines.map { [ it.supply, it.quantity, it.amount ] }).to eq([ [ supply, 20, 16_000 ], [ fungicide, 5, 1_500 ] ])
    expect(entry.amount).to eq(17_500)
    expect(entry.expense).to have_attributes(kind: "investment", amount: 17_500, category:, money_account: account, payee: "Agroservicio El Paraíso")
    expect(entry.expense.description).to eq("Compra de insumos: Urea × 20 saco, Fungicida × 5 litro")
    expect(entry.expense.receipt).to have_attributes(content_type: "application/pdf", filename: "factura.pdf")
    expect(AccountBalance.new.for(account)).to eq(32_500)
    expect(row).to have_attributes(entered: 20, in_warehouse: 20, available: 20)

    get sales_supply_entry_path(entry)
    expect(page.css("[data-supply-entry-lines] tbody tr").size).to eq(2)
    expect(page.at_css("a[href^='#{finance_expense_receipt_path(entry.expense.receipt)}']").text).to eq("Ver la factura")
  end

  it "asks for at least one supply" do
    post sales_supply_entries_path, params: { supply_entry: { received_on: Time.zone.today, finance_category_id: category.id,
                                                              money_account_id: account.id, payment_method: "cash" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("faltan: agrega al menos un insumo")
  end

  it "lends beyond the stock, says to whom it is owed, and delivers only what is in the warehouse" do
    create(:supply_entry, supply:, quantity: 10)
    loan = lend(15)
    expect(loan).to be_persisted
    expect(loan.supply_items.sole).not_to be_delivered
    expect(row).to have_attributes(lent: 15, delivered: 0, to_deliver: 15, in_warehouse: 10, available: -5)

    get sales_supply_stock_path
    available = page.at_css("tr#stock_supply_#{supply.id} [data-available]")
    expect(available.text.squish).to eq("-5 saco")
    expect(available.at_css("a")["href"]).to eq(sales_supply_deliveries_path(supply_id: supply.id))

    get sales_supply_deliveries_path(supply_id: supply.id)
    expect(page.at_css("[data-supply-deliveries] tbody tr").text.squish).to include("Rosa Mejía", "Urea", "15 saco", "Por entregar")

    line = loan.supply_items.sole
    patch sales_supply_delivery_path(line)
    expect(flash[:alert]).to include("No hay suficiente «Urea» en bodega para entregarlo: hay 10 saco")
    expect(line.reload).not_to be_delivered

    create(:supply_entry, supply:, quantity: 5)
    patch sales_supply_delivery_path(line)
    expect(line.reload).to have_attributes(delivered_on: Time.zone.today, delivered_by: admin)
    expect(row).to have_attributes(in_warehouse: 0, to_deliver: 0, available: 0)
    get sales_supply_deliveries_path
    expect(page.css("[data-supply-deliveries] tbody tr")).to be_empty

    delete sales_supply_delivery_path(line)
    expect(line.reload).not_to be_delivered
  end

  it "lets only administrators mark a delivery" do
    user = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "supplies", can_read: true, can_update: true) }
    create(:supply_entry, supply:, quantity: 10)
    line = lend(2).supply_items.sole
    sign_in user
    get sales_supply_deliveries_path
    expect(response).to have_http_status(:ok)
    expect(page.css("[data-supply-deliveries] form")).to be_empty
    patch sales_supply_delivery_path(line)
    expect(line.reload).not_to be_delivered
  end

  it "does not count the loans before the inventory started: they went out with their loan" do
    loan = lend(3, on: SupplyStock.starts_on - 1)
    expect(loan.supply_items.sole.delivered_on).to eq(loan.disbursed_on)
    expect(row).to have_attributes(lent: 0, available: 0)
  end

  it "removes an entry with its investment, unless what it brought was handed out" do
    entry = create(:supply_entry, supply:, quantity: 10)
    investment = entry.expense
    line = lend(4).supply_items.sole
    line.deliver!(admin)
    delete sales_supply_entry_path(entry)
    expect(SupplyEntry.exists?(entry.id)).to be(true)
    expect(flash[:alert]).to include("ya se entregó en préstamos lo que trajo de Urea")

    line.undeliver!
    delete sales_supply_entry_path(entry)
    expect(SupplyEntry.exists?(entry.id)).to be(false)
    expect(Expense.exists?(investment.id)).to be(false)
  end

  it "keeps its investment from being edited or removed in Control financiero" do
    entry = create(:supply_entry, supply:)
    expect(ExpensePolicy.new(admin, entry.expense)).to forbid_actions(%i[update destroy])
  end

  it "is a tab of its own, with the catalog moved from Préstamos" do
    user = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "stock", can_read: true) }
    sign_in user
    get sales_supply_stock_path
    expect(response).to redirect_to(root_path)
    get sales_supplies_path
    expect(response).to redirect_to(root_path)

    sign_in admin
    get sales_supplies_path
    expect(response).to have_http_status(:ok)
    expect(page.css("[data-supply-tabs] a").map { it.text.squish }).to eq([ "Inventario y entradas", "Por entregar", "Salidas", "Combustible", "Catálogo de insumos" ])
    expect(AppModule.submodules("loans")).not_to include("supplies")
  end
end
