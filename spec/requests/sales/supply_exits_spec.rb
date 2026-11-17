require "rails_helper"

# Supplies that leave without a loan (Fernando, 2026-11-14: «que se pueda
# registrar una salida de inventario, como que lo vendan por aparte»): sold
# to a person, its money comes into an account; used by the business, no
# money. Never more than is in the warehouse.
RSpec.describe "Supplies leaving without a loan" do
  let(:admin) { create(:user, :admin) }
  let(:supply) { create(:supply, name: "Urea", unit: "saco", default_price: 950) }
  let(:account) { create(:money_account, name: "Caja", opening_balance: 0) }
  let(:person) { create(:person, first_names: "Rosa", last_names: "Mejía") }

  def page = Nokogiri::HTML(response.body)
  def row = SupplyStock.new.for(supply)

  before do
    sign_in admin
    create(:supply_entry, supply:, quantity: 10, amount: 8_000)
  end

  def exit!(quantity: "3", unit_price: nil, lines: nil, **attributes)
    lines ||= { "0" => { supply_id: supply.id, quantity:, unit_price: }.compact }
    post sales_supply_exits_path, params: { supply_exit: { exited_on: Time.zone.today, lines_attributes: lines, **attributes } }
  end

  it "sells apart: takes it from the warehouse and what is left to lend, and its money comes into the account" do
    get new_sales_supply_exit_path(supply_id: supply.id)
    expect(page.at_css("#supply_exit_lines_attributes_0_unit_price")["value"]).to eq("950.0")
    expect(page.at_css("#supply_exit_lines_attributes_0_supply_id option[selected]")["data-stock"]).to eq("10.0")

    exit!(kind: "sale", person_id: person.id, unit_price: "1000", payment_method: "cash", money_account_id: account.id)
    supply_exit = SupplyExit.last
    expect(response).to redirect_to(sales_supply_exits_path)
    expect(flash[:notice]).to eq("Venta registrada: Urea × 3 saco. El dinero entró a la cuenta.")
    expect(supply_exit).to have_attributes(person:, amount: 3_000, money_account: account, created_by: admin)
    expect(row).to have_attributes(exited: 3, in_warehouse: 7, available: 7)
    expect(AccountBalance.new.for(account)).to eq(3_000)

    movement = MoneyMovements.new.all.find { it.source == "supply_sales" }
    expect(movement).to have_attributes(id: supply_exit.id, description: "Venta de insumo: Urea", person: "Rosa Mejía", amount_in: 3_000)
    get finance_incomes_path
    expect(response.body).to include("Venta de insumo: Urea")

    get sales_supply_stock_path
    expect(page.at_css("#stock_supply_#{supply.id} [data-exited]").text.squish).to eq("3 saco")

    get sales_supply_exits_path
    expect(page.css("[data-supply-exits] tbody tr").map { it.text.squish }).to contain_exactly(a_string_including("Venta por aparte", "Urea", "Rosa Mejía", "L 3,000.00"))
  end

  it "uses it in the business with no money, keeping none of a sale's data" do
    exit!(kind: "business_use", person_id: person.id, unit_price: "1000", payment_method: "cash", money_account_id: account.id)
    expect(SupplyExit.last).to have_attributes(kind: "business_use", person: nil, amount: nil, money_account: nil)
    expect(row.in_warehouse).to eq(7)
    expect(MoneyMovements.new.all.map(&:source)).not_to include("supply_sales")
  end

  it "never takes more than is in the warehouse, and asks a sale for its buyer, price and account" do
    expect { exit!(kind: "business_use", quantity: "11") }.not_to change(SupplyExit, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("«Urea» pasa de lo que hay en bodega (10 saco)")

    expect { exit!(kind: "sale") }.not_to change(SupplyExit, :count)
    expect(response.body).to include("Se le vendió a", "Precio por unidad (L)", "Cuenta")
  end

  it "takes several supplies at once, never more than there is of each adding its lines (Fernando, 2026-11-16)" do
    fungicide = create(:supply, name: "Fungicida", unit: "litro", default_price: 300)
    create(:supply_entry, supply: fungicide, quantity: 5, amount: 1_000)
    lines = { "0" => { supply_id: supply.id, quantity: "6", unit_price: "1000" }, "1" => { supply_id: supply.id, quantity: "5", unit_price: "1000" } }
    expect { exit!(kind: "sale", lines:, person_id: person.id, payment_method: "cash", money_account_id: account.id) }.not_to change(SupplyExit, :count)
    expect(response.body).to include("«Urea» pasa de lo que hay en bodega (10 saco)")

    lines = { "0" => { supply_id: supply.id, quantity: "6", unit_price: "1000" }, "1" => { supply_id: fungicide.id, quantity: "2", unit_price: "300" },
              "2" => { supply_id: "", quantity: "" } }
    exit!(kind: "sale", lines:, person_id: person.id, payment_method: "cash", money_account_id: account.id)
    supply_exit = SupplyExit.last
    expect(flash[:notice]).to eq("Venta registrada: Urea × 6 saco, Fungicida × 2 litro. El dinero entró a la cuenta.")
    expect(supply_exit.lines.map { [ it.supply, it.quantity, it.amount ] }).to eq([ [ supply, 6, 6_000 ], [ fungicide, 2, 600 ] ])
    expect(supply_exit.amount).to eq(6_600)
    expect(SupplyStock.new.for(fungicide).in_warehouse).to eq(3)
    expect(MoneyMovements.new.all.find { it.source == "supply_sales" }.description).to eq("Venta de insumo: Urea, Fungicida")

    get sales_supply_exit_path(supply_exit)
    expect(page.css("[data-supply-exit-lines] tbody tr").size).to eq(2)
    get sales_supply_exits_path(supply_id: fungicide.id)
    expect(page.css("[data-supply-exits] tbody tr").size).to eq(1)
  end

  it "is removed: what left goes back to the warehouse and the money out of the account" do
    supply_exit = create(:supply_exit, supply:, quantity: 4, money_account: account, unit_price: 500)
    expect(AccountBalance.new.for(account)).to eq(2_000)

    get sales_supply_exit_path(supply_exit)
    expect(response.body).to include("Su dinero entró a «Caja»")
    delete sales_supply_exit_path(supply_exit)
    expect(flash[:notice]).to eq("Se quitó la salida: lo que salió volvió a la bodega.")
    expect(row.in_warehouse).to eq(10)
    expect(AccountBalance.new.for(account)).to eq(0)
  end

  it "keeps an entry whose supplies left from being removed, and moves them when merging people" do
    supply_exit = create(:supply_exit, supply:, quantity: 8, person:)
    entry = SupplyEntry.last
    expect(entry.destroy).to be(false)

    other = create(:person)
    expect(PersonMerge.new(primary: other, secondary: person).save).to be(true)
    expect(supply_exit.reload.person).to eq(other)
  end

  it "is for whoever edits Insumos, and each sees what they registered" do
    seller = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "supplies", can_read: true, can_create: true) }
    mine = create(:supply_exit, supply:, quantity: 1, created_by: seller)
    theirs = create(:supply_exit, supply:, quantity: 1, created_by: admin)
    sign_in seller

    get picker_search_path(:people, q: "Ros")
    expect(response).to have_http_status(:ok)
    get sales_supply_exits_path
    expect(response.body).to include(dom_id_for(mine))
    expect(response.body).not_to include(dom_id_for(theirs))

    reader = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "supplies", can_read: true) }
    sign_in reader
    exit!(kind: "business_use")
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")
  end

  def dom_id_for(record) = ActionView::RecordIdentifier.dom_id(record)
end
