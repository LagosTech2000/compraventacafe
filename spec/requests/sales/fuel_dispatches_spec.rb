require "rails_helper"

# Fuel and oil of the business (Fernando, 2026-11-22): a supply «De la
# empresa» is not lent; each dispatch is a use of the business with its
# vehicle and, optional, the purchase it went for; «Combustible» sums the
# liters by day and by vehicle, their cost and what is left.
RSpec.describe "Fuel of the business dispatched to the vehicles" do
  let(:admin) { create(:user, :admin) }
  let(:gas) { create(:supply, name: "Gasolina", unit: "litro", default_price: 110, business_use: true) }
  let(:truck) { create(:vehicle, plate: "HAA 1234") }
  let(:pickup) { create(:vehicle, plate: "HBB 5678") }

  def page = Nokogiri::HTML(response.body)

  def dispatch(quantity:, vehicle: nil, purchase: nil, on: Time.zone.today)
    post sales_supply_exits_path, params: { supply_exit: {
      kind: "business_use", exited_on: on, vehicle_id: vehicle&.id, purchase_id: purchase&.id,
      lines_attributes: { "0" => { supply_id: gas.id, quantity: } }
    } }
  end

  before do
    create(:supply_entry, supply: gas, quantity: 200, amount: 22_000) # L 110 per liter
    sign_in admin
  end

  it "asks the vehicle for fuel of the business and takes the purchase's" do
    expect { dispatch(quantity: 35) }.not_to change(SupplyExit, :count)
    expect(response.body).to include("el combustible o el aceite de la empresa va a un vehículo")

    purchase = create(:purchase, vehicle: pickup)
    dispatch(quantity: 20, purchase:)
    expect(SupplyExit.last).to have_attributes(vehicle: pickup, purchase:)

    get trading_purchase_path(purchase)
    expect(page.at_css("[data-purchase-vehicle]").text).to include("HBB 5678", "20 litro de Gasolina")
  end

  it "sums the liters by day and by vehicle, their cost and what is left" do
    dispatch(quantity: 35, vehicle: truck)
    dispatch(quantity: 20, vehicle: pickup)
    dispatch(quantity: 10, vehicle: truck, on: Time.zone.today - 1)

    get sales_fuel_dispatches_path(from: Time.zone.today - 5)
    expect(page.at_css("[data-fuel-stock='#{gas.id}'] dd").text.strip).to eq("135 litro")
    expect(page.at_css("[data-fuel-total='#{gas.id}'] dd").text.strip).to eq("65 litro")
    expect(page.at_css("[data-fuel-total='cost'] dd").text.strip).to eq("L 7,150.00")
    by_vehicle = page.css("[data-fuel-table='by_vehicle'] tbody tr").map { it.css("td").map { it.text.strip } }
    expect(by_vehicle.first).to include("45 litro", "2", "L 4,950.00")
    expect(by_vehicle.first.first).to start_with("HAA 1234")
    expect(page.css("[data-fuel-table='by_day'] tbody tr").size).to eq(2)

    get sales_fuel_dispatches_path(from: Time.zone.today - 5, vehicle_id: pickup.id)
    expect(page.at_css("[data-fuel-total='#{gas.id}'] dd").text.strip).to eq("20 litro")
  end

  it "offers the vehicle in «Nueva compra», the business's own first" do
    own = create(:vehicle, plate: "PROPIO 1", own: true)
    truck
    get new_trading_purchase_path
    options = page.css("#purchase_vehicle_id option").map(&:text)
    expect(options.first).to eq("Sin vehículo asignado")
    expect(options.second).to start_with(own.plate)
  end

  it "does not lend a supply of the business" do
    loan = build(:loan, cash_amount: 0, supply_items_attributes: [ { supply_id: gas.id, quantity: 2, unit_price: 110 } ])
    expect(loan).not_to be_valid
    expect(loan.errors.full_messages.to_sentence).to include("es de la empresa: no se presta")
  end

  it "marks a supply as of the business from the catalog" do
    supply = create(:supply)
    patch sales_supply_path(supply), params: { supply: { business_use: "1" } }
    expect(supply.reload).to be_business_use
    get sales_supplies_path
    expect(response.body).to include("De la empresa")
  end

  it "lets who sees Insumos see it, and nobody else", :all_records do
    viewer = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "supplies", can_read: true) }
    sign_in viewer
    get sales_fuel_dispatches_path
    expect(response).to have_http_status(:ok)
    other = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "shipments", can_read: true) }
    sign_in other
    get sales_fuel_dispatches_path
    expect(response).to redirect_to(root_path)
  end

  # Only a purchase of the dispatch's day that went with a vehicle (Fernando, 2026-11-23), and its cost.
  it "takes only a purchase of its day with a vehicle, and says what it cost" do
    yesterday = create(:purchase, vehicle: truck, purchased_at: 1.day.ago)
    no_vehicle = create(:purchase)
    get new_sales_supply_exit_path(kind: "business_use")
    options = page.css("#supply_exit_purchase_id option[data-day]").map { it["value"].to_i }
    expect(options).to include(yesterday.id)
    expect(options).not_to include(no_vehicle.id)

    dispatch(quantity: 10, purchase: yesterday)
    expect(response.body).to include("es de otro día")
    dispatch(quantity: 10, vehicle: truck, purchase: no_vehicle)
    expect(response.body).to include("no tiene vehículo")

    dispatch(quantity: 10, vehicle: truck)
    expect(SupplyExit.last.use_cost).to eq(1_100)
    get sales_supply_exit_path(SupplyExit.last)
    expect(response.body).to include("Costo del despacho", "L 1,100.00")
  end
end
