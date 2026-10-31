require "rails_helper"

# Comercialización on screen: the truck's weighing calculated while typing
# (weighing_calculator_controller.js), the difference with the buyer's scale
# and «Nueva venta» adding up the chosen shipments (sale_builder_controller.js).
RSpec.describe "Sales screens", type: :system do
  let(:user) { create(:user, :admin) }
  let!(:buyer) { create(:buyer, name: "Beneficio Henola") }

  def calculated(name) = find("[data-weighing-calculator-target='#{name}']").text

  before { sign_in_as(user) }

  it "registers a carrier and a truck from the shipment form and picks them" do
    visit new_sales_shipment_path
    click_link "Nuevo transportista"
    within("dialog[open]") do
      fill_in "carrier_name", with: "Fletes del Norte"
      find("[type=submit]").click
    end
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_select("shipment_carrier_id", selected: "Fletes del Norte")

    click_link "Nuevo camión"
    within("dialog[open]") do
      fill_in "truck_plate", with: "hbb 4321"
      find("[type=submit]").click
    end
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_select("shipment_truck_id", selected: "HBB 4321")
  end

  # Client, 2026-10-30: a carrier (with its trip price) or a driver, one or the other.
  it "shows the carrier and its trip price or the driver, never both" do
    visit new_sales_shipment_path
    expect(page).to have_checked_field("Un transportista")
    expect(page).to have_field("shipment_trip_price")
    expect(page).to have_no_field("shipment_driver_name")

    choose "Un motorista"
    expect(page).to have_field("shipment_driver_name")
    expect(page).to have_no_field("shipment_carrier_id")
    expect(page).to have_no_field("shipment_trip_price")
    expect(page).to have_field("shipment_truck_id")

    choose "Un transportista"
    expect(page).to have_field("shipment_carrier_id")
    expect(page).to have_no_field("shipment_driver_name")
  end

  it "calculates a shipment while typing, warns over the stock and saves it" do
    create(:purchase, gross_weight: 500) # (500 − 4) × 0.49 = 243.04 lb in stock
    visit new_sales_shipment_path
    select "Beneficio Henola", from: "shipment_buyer_id"
    fill_in "shipment_origin_gross_weight", with: "1000"
    fill_in "shipment_origin_sacks", with: "6"

    # (1,000 − 6) × 0.49
    expect(page).to have_css("[data-weighing-calculator-target='net']", text: "487.06")
    expect(calculated("tare")).to eq("6.00")
    expect(page).to have_css("[data-weighing-calculator-target='stockNotice']", text: "243.04", visible: true)

    select "Uva", from: "shipment_coffee_state"
    expect(page).to have_field("shipment_origin_yield_factor", with: "0.186")
    expect(page).to have_no_field("shipment_origin_humidity_percent")
    # (1,000 − 6) × 0.186
    expect(page).to have_css("[data-weighing-calculator-target='net']", text: "184.88")

    click_button "Registrar salida"
    expect(page).to have_text("Salida 0001 registrada para Beneficio Henola")
    expect(Shipment.last).to have_attributes(coffee_state: "cherry", origin_net_weight: BigDecimal("184.88"))
  end

  it "weighs the truck by weighings, as a purchase" do
    visit new_sales_shipment_path
    select "Beneficio Henola", from: "shipment_buyer_id"
    choose "Por pesadas"
    expect(page).to have_field("shipment_origin_gross_weight", readonly: true)
    within(all("[data-weighing-calculator-target='weighing']").last) do
      fill_in "Peso de la pesada (lb)", with: "600"
      fill_in "Sacos de la pesada", with: "4"
    end
    click_button "Agregar pesada"
    within(all("[data-weighing-calculator-target='weighing']").last) do
      fill_in "Peso de la pesada (lb)", with: "400"
      fill_in "Sacos de la pesada", with: "2"
    end
    expect(page).to have_field("shipment_origin_gross_weight", with: "1000.00")
    expect(page).to have_field("shipment_origin_sacks", with: "6")
    expect(page).to have_css("[data-weighing-calculator-target='net']", text: "487.06")

    click_button "Registrar salida"
    expect(page).to have_text("Salida 0001 registrada")
    expect(Shipment.last).to have_attributes(origin_weight_mode: "weighings", origin_gross_weight: 1_000, origin_sacks: 6)
    expect(Shipment.last.weighings.map(&:gross_weight)).to eq([ 600, 400 ])
  end

  it "shows the difference with the local scale while weighing at destination, marked over the tolerance" do
    SiteSetting.instance.update!(weight_tolerance_percent: 1)
    shipment = create(:shipment, buyer:)
    visit edit_sales_shipment_arrival_path(shipment)

    fill_in "shipment_destination_gross_weight", with: "980"
    fill_in "shipment_destination_damage_percent", with: "1"
    # (980 − 6) × 0.49 × 0.99 = 472.49: 14.57 lb (2.99 %) less than 487.06
    expect(page).to have_css("[data-weighing-calculator-target='difference']", text: "−14.57 lb (−2.99 %)")
    expect(page).to have_css("[data-weighing-calculator-target='differenceBox'][data-over-tolerance='true']")

    click_button "Guardar peso en destino"
    expect(page).to have_text("Peso en destino de la salida 0001 guardado")
    expect(shipment.reload.destination_net_weight).to eq(BigDecimal("472.49"))
  end

  it "adds up the chosen shipments, warns when their states mix, and sells" do
    first = create(:shipment, :received, buyer:)   # 482.16 lb at the buyer's
    second = create(:shipment, :received, buyer:)
    create(:shipment, :received, buyer:, coffee_state: "dry_parchment", origin_humidity_percent: 12, destination_humidity_percent: 12)
    visit new_sales_sale_path(buyer_id: buyer.id)

    fill_in "sale_unit_price", with: "6000"
    expect(page).to have_css("[data-sale-builder-target='mixed']", visible: true)

    uncheck dom_id(Shipment.find_by(coffee_state: "dry_parchment"), :select)
    expect(page).to have_css("[data-sale-builder-target='mixed']", visible: false)
    # 964.32 lb ÷ 120 (by default) × L 6,000
    expect(page).to have_css("[data-sale-builder-target='total']", text: "L 48,216.00")
    expect(page).to have_css("[data-sale-builder-target='quintals']", text: "8.04")
    # The scales' difference, also in lempiras at the price typed: 9.80 lb × L 50
    expect(page).to have_css("[data-sale-builder-target='difference']", text: "−9.80 lb")
    expect(page).to have_css("[data-sale-builder-target='differenceMoney']", text: "L 490.00 que no se cobran a este precio")

    choose "Por libra"
    fill_in "sale_unit_price", with: "60"
    expect(page).to have_css("[data-sale-builder-target='total']", text: "L 57,859.20")
    expect(page).to have_css("[data-sale-builder-target='differenceMoney']", text: "L 588.00")

    select "De contado (cobrada completa)", from: "sale_payment_status"
    select "Transferencia", from: "sale_payment_method"
    click_button "Registrar venta"
    expect(page).to have_text("Venta 0001 registrada")
    expect(Sale.last).to have_attributes(total: BigDecimal("57859.20"), payment_status: "paid")
    expect(Sale.last.shipments).to contain_exactly(first, second)
  end

  it "names the price after its unit and takes the pounds of the quintal, 120 unless changed" do
    create(:shipment, :received, buyer:) # 482.16 lb at the buyer's
    visit new_sales_sale_path(buyer_id: buyer.id)
    total = "[data-sale-builder-target='total']"

    expect(page).to have_field("sale_quintal_pounds", with: "120")
    expect(page).to have_css("label[for=sale_unit_price]", text: "Precio por quintal (L)")
    fill_in "sale_unit_price", with: "6000"
    expect(page).to have_css(total, text: "L 24,108.00")

    fill_in "sale_quintal_pounds", with: "100"
    expect(page).to have_css(total, text: "L 28,929.60")
    expect(page).to have_css("[data-sale-builder-target='quintals']", text: "4.82")

    choose "Por libra"
    expect(page).to have_css("label[for=sale_unit_price]", text: "Precio por libra (L)")
    expect(page).to have_no_field("sale_quintal_pounds")
    choose "Por quintal"
    expect(page).to have_css("label[for=sale_unit_price]", text: "Precio por quintal (L)")

    click_button "Registrar venta"
    expect(page).to have_text("Venta 0001 registrada")
    expect(Sale.last).to have_attributes(quintal_pounds: 100, total: BigDecimal("28929.60"))
  end

  it "says what the advance taken off is in coffee, net and gross, at the price typed" do
    create(:buyer_advance, buyer:, amount: 5_000)
    create(:shipment, :received, buyer:) # 482.16 lb net, 990 gross at the buyer's
    visit new_sales_sale_path(buyer_id: buyer.id)

    fill_in "sale_unit_price", with: "6000"
    fill_in "sale_advance_amount", with: "3000"
    # L 3,000 ÷ L 50 a pound (L 6,000 ÷ 120 lb)
    expect(page).to have_text("Equivale a 60.00 lb netas y 123.20 lb brutas de café, a este precio.")

    choose "Por libra"
    fill_in "sale_unit_price", with: "60"
    expect(page).to have_text("Equivale a 50.00 lb netas y 102.66 lb brutas de café, a este precio.")
  end

  def dom_id(record, prefix) = ActionView::RecordIdentifier.dom_id(record, prefix)
end
