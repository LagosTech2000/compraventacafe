require "rails_helper"

# What «Nueva compra» shows around the producer (Fernando, 2026-10-18): the
# farm's empty details with «Completar datos de la finca», a new carrero
# from the form, the producer's card, and the zone a producer without one takes.
RSpec.describe "Purchase form extras", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "says which details the farm chosen is missing, and updates once they are completed in the modal" do
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    create(:farm, producer:, name: "La Loma")
    create(:farm, producer:, name: "El Cerro", area_value: 2, area_unit: "manzana", latitude: 14.1, longitude: -87.2,
                  department: Department.first, municipality: Department.first.municipalities.first, address_line: "Aldea")
    visit new_trading_purchase_path
    pick_record "producer_search", producer.picker_label
    fill_in "purchase_gross_weight", with: "330"

    select "El Cerro", from: "purchase_farm_id"
    expect(page).to have_no_css("[data-farm-gaps-target='notice']", visible: true)

    select "La Loma", from: "purchase_farm_id"
    expect(page).to have_css("[role=status]", text: "A esta finca le faltan datos por ingresar: Extensión, Dirección, Ubicación en el mapa.")
    within("[data-farm-gaps-target='notice']") { click_link "Completar datos de la finca" }
    within("dialog[open]") do
      fill_in "farm_area_manzana", with: "3"
      find("[type=submit]").click
    end

    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_css("[role=status]", text: "A esta finca le faltan datos por ingresar: Dirección, Ubicación en el mapa.")
    expect(page).to have_field("purchase_gross_weight", with: "330")
    expect(page).to have_select("purchase_farm_id", selected: "La Loma")
    expect(producer.farms.find_by(name: "La Loma").area_value).to eq(3)
  end

  it "registers a carrero from the purchase and chooses them with their commission" do
    visit new_trading_purchase_path
    click_link "Nuevo carrero"
    within("dialog[open]") do
      fill_in "hauler_price_per_pound", with: "0.3"
      fill_in "hauler_person_attributes_first_names", with: "Pedro"
      fill_in "hauler_person_attributes_last_names", with: "Cruz"
      find("[type=submit]").click
    end

    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_select("purchase_hauler_id", selected: "Pedro Cruz")
    expect(page).to have_css("[data-hauler-commission-target='terms']", text: "L 0.30 por libra neta")
  end

  it "shows the producer's card beside the form" do
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    create(:purchase, producer:, gross_weight: 1000)
    visit new_trading_purchase_path
    expect(page).to have_css("turbo-frame#producer-card", text: "¿A quién se le compra?")

    pick_record "producer_search", producer.picker_label
    within("turbo-frame#producer-card") do
      expect(page).to have_text("Ana Zelaya").and have_text("1 compra").and have_text("Sin facturar")
    end
  end

  it "gives the purchase's zone to a producer without one" do
    zone = create(:zone, name: "El Rosario")
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    visit new_trading_purchase_path
    pick_record "producer_search", producer.picker_label
    select "El Rosario", from: "purchase_zone_id"
    fill_in "purchase_gross_weight", with: "330"
    fill_in "purchase_price_per_pound", with: "58"
    within("main form") { find("[type=submit]").click }

    expect(page).to have_text("Ana Zelaya no tenía zona: quedó en El Rosario.")
    expect(producer.person.reload.zone).to eq(zone)
  end
end
