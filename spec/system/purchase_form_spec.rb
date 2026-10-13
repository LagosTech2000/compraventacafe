require "rails_helper"

# The live preview of the purchase calculation (purchase_calculator_controller.js).
RSpec.describe "Purchase form preview", type: :system do
  let(:user) { create(:user, :admin) }

  before do
    sign_in_as(user)
    visit new_trading_purchase_path
  end

  def figure(name) = find("[data-purchase-calculator-target='#{name}']").text

  def figures
    %w[sacks tare damageWeight damageAmount netWeight quintals total].to_h { |name| [ name, figure(name) ] }
  end

  it "takes the damage off in pounds and lempiras" do
    fill_in "purchase_gross_weight", with: "1000"
    fill_in "purchase_damage_percent", with: "2.5"
    fill_in "purchase_price_per_pound", with: "60"

    # (1000 − 7) × 0.49 = 486.57; 2.5 % of damage = 12.16 lb = L 729.60
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "474.41")
    expect(figures).to include("tare" => "7.00", "damageWeight" => "12.16", "damageAmount" => "L 729.60", "total" => "L 28,464.60")
  end

  it "keeps calculating when the damage is cleared, as 0 %" do
    fill_in "purchase_gross_weight", with: "1000"
    fill_in "purchase_price_per_pound", with: "60"
    fill_in "purchase_damage_percent", with: "2.5"
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "474.41")

    fill_in "purchase_damage_percent", with: ""
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "486.57")
    expect(figures).to include("damageWeight" => "0.00", "damageAmount" => "L 0.00", "quintals" => "3.89", "total" => "L 29,194.20")
  end

  it "keeps sacks and tare while the humidity is missing" do
    fill_in "purchase_gross_weight", with: "1000"
    fill_in "purchase_humidity_percent", with: ""

    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "—")
    expect(figures).to include("sacks" => "6.06", "tare" => "7.00", "total" => "—")
  end

  it "uses the yield in cherry and the damage again back in parchment" do
    fill_in "purchase_gross_weight", with: "1000"
    fill_in "purchase_price_per_pound", with: "10"
    select "Uva", from: "purchase_coffee_state"
    # (1000 − 7) × 0.186 = 184.70
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "184.70")
    expect(page).to have_no_field("purchase_damage_percent")

    select "Pergamino húmedo", from: "purchase_coffee_state"
    expect(page).to have_field("purchase_damage_percent", with: "0")
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "486.57")
  end

  it "keeps the calculation and the buttons on the right on wide screens, and below on phones" do
    box = ->(selector) { page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return [r.left, r.top] })()") }

    calculation_left, = box.call("aside")
    gross_left, = box.call("#purchase_gross_weight")
    expect(calculation_left).to be > gross_left + 400

    page.driver.resize(390, 900)
    expect(page).to have_css("aside")
    _, calculation_top = box.call("aside")
    _, observations_top = box.call("#purchase_observations")
    expect(calculation_top).to be > observations_top
  end

  it "lists only the farms of the producer picked, and follows a change of producer" do
    ana = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    bruno = create(:producer, person: create(:person, first_names: "Bruno", last_names: "Aguilar"))
    ana.farms.create!(name: "El Mirador")
    ana.farms.create!(name: "Santa Rosa")
    bruno.farms.create!(name: "Las Brisas")
    create(:farm, name: "Finca del negocio")
    visit new_trading_purchase_path
    farm_options = -> { all("#purchase_farm_id option").map(&:text) }

    expect(farm_options.call).to eq([ "Sin finca asignada" ])
    expect(page).to have_text("Elige primero el productor")

    fill_in "producer_search", with: ana.picker_label
    expect(page).to have_select("purchase_farm_id", options: [ "Sin finca asignada", "El Mirador", "Santa Rosa" ])
    select "Santa Rosa", from: "purchase_farm_id"

    fill_in "producer_search", with: bruno.picker_label
    expect(page).to have_select("purchase_farm_id", options: [ "Sin finca asignada", "Las Brisas" ], selected: "Sin finca asignada")
    expect(page).to have_link("Nueva finca", href: /producer_id=#{bruno.id}/)
  end

  it "offers the farms of a producer registered from the purchase form" do
    visit new_trading_purchase_path
    click_link "¿No está? Registrar productor"
    within("dialog[open]") do
      fill_in "producer_person_attributes_first_names", with: "Carla"
      fill_in "producer_person_attributes_last_names", with: "Mejía"
      first("input[name='producer[new_farm_names][]']").fill_in(with: "El Cerro")
      find("[type=submit]").click
    end
    expect(page).to have_field("producer_search", with: /Carla Mejía/)
    expect(page).to have_select("purchase_farm_id", options: [ "Sin finca asignada", "El Cerro" ])
  end

  it "says which details the producer picked is missing, and updates once they are completed in the modal" do
    zone = create(:zone, name: "El Rosario")
    complete = create(:producer, ihcafe_code: "AB-12-34567",
                                 person: create(:person, first_names: "Ana", last_names: "Zelaya", dni: "0801199912345", rtn: "08011999123456",
                                                         phone: "99990000", email: "ana@example.com", zone:, address_line: "Aldea",
                                                         department: Department.first, municipality: Department.first.municipalities.first))
    partial = create(:producer, person: create(:person, first_names: "Bruno", last_names: "Aguilar", phone: "99990000"))
    visit new_trading_purchase_path

    fill_in "producer_search", with: complete.picker_label
    expect(page).to have_no_css("[data-producer-gaps-target='notice']", visible: true)

    fill_in "producer_search", with: partial.picker_label
    expect(page).to have_css("[role=status]",
                             text: "A este productor le faltan datos por ingresar: DNI, RTN, Correo electrónico, Zona, Dirección, Clave IHCAFE.")
    fill_in "purchase_gross_weight", with: "330"

    within("[data-producer-gaps-target='notice']") { click_link "Completar datos" }
    within("dialog[open]") do
      fill_in "producer_ihcafe_code", with: "CD-34-56789"
      select "El Rosario", from: "producer_person_attributes_zone_id"
      find("[type=submit]").click
    end
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_css("[role=status]", text: "le faltan datos por ingresar: DNI, RTN, Correo electrónico, Dirección.")
    expect(page).to have_field("purchase_gross_weight", with: "330")
    expect(page).to have_select("purchase_zone_id", selected: "El Rosario")
    expect(partial.reload.ihcafe_code).to eq("CD-34-56789")
  end
end
