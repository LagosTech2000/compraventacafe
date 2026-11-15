require "rails_helper"

# «Registrar salida» of supplies (Fernando, 2026-11-14; supply_exit_controller.js):
# a sale asks its buyer, price and account; a use of the business does not;
# the supply puts its price and says what is in the warehouse.
RSpec.describe "Supply exit form", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:supply) { create(:supply, name: "Urea", unit: "saco", default_price: 1_250) }
  let!(:account) { create(:money_account, name: "Caja", default_for: %w[cash]) }

  before do
    create(:supply_entry, supply:, quantity: 1_500, amount: 8_000)
    create(:person, first_names: "Rosa", last_names: "Mejía")
    sign_in_as(admin)
  end

  it "sells with the supply's price and the total as typed, and warns past what is in the warehouse" do
    visit new_sales_supply_exit_path
    select "Urea", from: "supply_exit_supply_id"
    expect(page).to have_text("En bodega: 1,500 saco")
    expect(find_field("supply_exit_unit_price").value).to eq("1250.00")

    fill_in "supply_exit_quantity", with: "1600"
    expect(page).to have_text("No hay tanto en bodega: hay 1,500 saco.")
    fill_in "supply_exit_quantity", with: "1000"
    expect(page).to have_no_text("No hay tanto en bodega")
    expect(page).to have_css("[data-supply-exit-target=total]", text: "L 1,250,000.00")

    pick_record("person_search", "Rosa Mejía")
    click_button "Registrar salida"
    expect(page).to have_text("Venta registrada: Urea × 1,000 saco.")
    expect(SupplyExit.last).to have_attributes(kind: "sale", quantity: 1_000, amount: 1_250_000, money_account: account)
  end

  it "registers a use of the business without asking for a buyer" do
    visit new_sales_supply_exit_path(supply_id: supply.id)
    choose "Uso del negocio"
    expect(page).to have_no_field("person_search")
    fill_in "supply_exit_quantity", with: "5"
    click_button "Registrar salida"
    expect(page).to have_text("Salida registrada: Urea × 5 saco.")
    expect(SupplyExit.last).to have_attributes(kind: "business_use", person: nil, amount: nil)
  end
end
