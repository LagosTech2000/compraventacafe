require "rails_helper"

# The map chart of Reportería draws a circle per place, the biggest for the
# largest figure, and opens its page from the point.
RSpec.describe "Report maps", type: :system do
  it "draws a circle per producer, sized by what they sold" do
    big = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya", latitude: 14.1, longitude: -86.9))
    small = create(:producer, person: create(:person, first_names: "Beto", last_names: "Mejía", latitude: 14.2, longitude: -86.8))
    create(:purchase, producer: big, gross_weight: 4000)
    create(:purchase, producer: small, gross_weight: 200)
    sign_in_as(create(:user, :admin))
    visit reports_report_path("producers", period: "all")

    within("figure", text: "Dónde están los productores") do
      expect(page).to have_css("path.leaflet-interactive", count: 2)
      expect(page.evaluate_script("[...document.querySelectorAll('[data-controller=report-map] .leaflet-control-zoom a')].map((a) => a.title)"))
        .to eq(%w[Acercar Alejar])
      radii = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("[data-controller=report-map] path.leaflet-interactive")].map((path) => path.getBBox().width)
      JS
      expect(radii.max).to be > radii.min * 2
      all("path.leaflet-interactive").max_by { it.evaluate_script("this.getBBox().width") }.click
      expect(page).to have_css(".leaflet-popup", text: "Ana Zelaya")
      expect(page).to have_css(".leaflet-popup-close-button[aria-label='Cerrar']")
      within(".leaflet-popup") { click_link "Abrir" }
    end
    expect(page).to have_current_path(trading_producer_path(big))
  end
end
