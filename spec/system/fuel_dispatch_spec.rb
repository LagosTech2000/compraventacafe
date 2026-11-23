require "rails_helper"

# A dispatch of the business's fuel (supply_exit_controller.js, Fernando,
# 2026-11-22): a use of the business shows the vehicle and the purchase,
# asks the vehicle for fuel of the business and takes the purchase's.
RSpec.describe "Dispatching fuel to a vehicle", type: :system do
  let(:admin) { create(:user, :admin) }

  before { sign_in_as(admin) }

  it "asks the vehicle for fuel of the business and takes the purchase's vehicle" do
    gas = create(:supply, name: "Gasolina", unit: "litro", business_use: true)
    create(:supply_entry, supply: gas, quantity: 100, amount: 11_000)
    vehicle = create(:vehicle, plate: "HAA 1234")
    purchase = create(:purchase, vehicle:)

    visit new_sales_supply_exit_path
    expect(page).to have_no_select("supply_exit_vehicle_id")
    choose "Uso del negocio"
    select "Gasolina", from: "supply_exit_lines_attributes_0_supply_id"
    expect(find("#supply_exit_vehicle_id")[:required]).to be_truthy
    find("#supply_exit_purchase_id option[value='#{purchase.id}']").select_option
    expect(page).to have_select("supply_exit_vehicle_id", selected: vehicle.label)
    fill_in "supply_exit_lines_attributes_0_quantity", with: "30"
    click_button "Registrar salida"

    expect(page).to have_text("Salida registrada")
    expect(SupplyExit.last).to have_attributes(vehicle:, purchase:)
  end
end
