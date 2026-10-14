require "rails_helper"

# Where a farm or a person is, on a map (Fernando, 2026-10-13): OpenStreetMap
# with Leaflet (no tiles in specs: they never reach the internet).
RSpec.describe "Locations on a map", type: :system do
  let(:admin) { create(:user, :admin) }

  def field_value(id) = find_field(id).value

  it "puts the pin with a tap, saves the farm's point and shows it on its page" do
    sign_in_as(admin)
    visit new_farms_farm_path
    fill_in "farm_name", with: "El Mirador"
    expect(page).to have_css(".leaflet-container")
    expect(page).to have_no_css(".map-pin")
    expect(page).to have_button("Quitar del mapa", visible: :hidden)

    find("[data-location-map-target=map]").click
    expect(page).to have_css(".map-pin")
    expect(field_value("farm_latitude")).to match(/\A1[45]\.\d{6}\z/) # Honduras in view
    expect(field_value("farm_longitude")).to match(/\A-8[6-8]\.\d{6}\z/)
    latitude = field_value("farm_latitude").to_d

    within("main form") { find("[type=submit]").click }
    expect(page).to have_text("Finca registrada.")
    farm = Farm.find_by!(name: "El Mirador")
    expect(farm.latitude).to eq(latitude)

    visit farms_farm_path(farm)
    expect(page).to have_css(".leaflet-container .map-pin")
    expect(page).to have_link("Abrir en Google Maps", href: "https://www.google.com/maps/search/?api=1&query=#{farm.latitude},#{farm.longitude}")
  end

  it "moves the pin with typed coordinates, and takes it out" do
    farm = create(:farm, latitude: 14.072275, longitude: -87.192136)
    sign_in_as(admin)
    visit farms_farm_path(farm)
    click_link "Editar"

    within("dialog[open]") do
      expect(page).to have_css(".map-pin")
      expect(field_value("farm_latitude")).to eq("14.072275")
      # The map in the modal takes its size once the window opens.
      expect(page.evaluate_script("document.querySelector('dialog[open] .leaflet-container').getBoundingClientRect().height")).to be > 200

      fill_in "farm_latitude", with: "15.504"
      fill_in "farm_longitude", with: "-88.025"
      expect(page.evaluate_script("document.querySelector('dialog[open] .map-pin') !== null")).to be(true)

      click_button "Quitar del mapa"
      expect(page).to have_no_css(".map-pin")
      expect(field_value("farm_latitude")).to eq("")
      find("[type=submit]").click
    end
    expect(page).to have_no_css("dialog[open]")
    expect(farm.reload).to have_attributes(latitude: nil, longitude: nil)
    expect(page).to have_no_link("Abrir en Google Maps")
  end

  it "takes a person's point from their form" do
    person = create(:person, :client)
    sign_in_as(admin)
    visit edit_administration_person_path(person)
    fill_in "person_latitude", with: "14.1"
    fill_in "person_longitude", with: "-87.2"
    expect(page).to have_css(".map-pin")
    within("main form") { find("[type=submit]").click }
    expect(page).to have_css(".leaflet-container .map-pin")
    expect(person.reload).to have_attributes(latitude: 14.1.to_d, longitude: -87.2.to_d)
  end
end
