require "rails_helper"

# Every list with filters filters as the user goes (Fernando, 2026-10-18:
# the same everywhere), without a button and without reloading the page;
# how many there are and the active filters show above the results.
RSpec.describe "Live lists", type: :system do
  let(:user) { create(:user, :admin) }

  def mark_page = page.execute_script("document.body.dataset.pageMarker = 'still here'")
  def page_reloaded? = page.evaluate_script("document.body.dataset.pageMarker") != "still here"

  before do
    ana = create(:producer, person: create(:person, :collaborator, first_names: "Ana", last_names: "Zelaya"))
    luis = create(:producer, person: create(:person, first_names: "Luis", last_names: "Mejía"))
    create(:zone, name: "Zona Zelaya")
    create(:zone, name: "Zona Mejía")
    create(:farm, name: "Zelaya de arriba")
    create(:farm, name: "Mejía de abajo", producer: luis)
    create(:hauler, person: ana.person)
    create(:hauler, person: luis.person)
    create(:loan, person: ana.person)
    create(:loan, person: luis.person)
    create(:supply, name: "Zelaya urea")
    create(:supply, name: "Mejía abono")
    create(:expense_category, name: "Zelaya combustible")
    create(:expense_category, name: "Mejía comida")
    sign_in_as(user)
  end

  {
    "/administration/people" => "people-list", "/administration/zones" => "admin-zones-list",
    "/administration/farms" => "admin-farms-list", "/trading/haulers" => "haulers-list",
    "/trading/producers" => "producers-list", "/trading/zones" => "zones-list", "/loans/loans" => "loans-list",
    "/loans/credit_accounts" => "credit-accounts-list", "/loans/supplies" => "supplies-list",
    "/farms/farms" => "farms-list", "/farms/expense_categories" => "expense-categories-list"
  }.each do |path, frame|
    it "filters #{path} as the user types, in its frame" do
      visit path
      mark_page
      expect(page).to have_no_button("Filtrar")
      expect(page).to have_css("##{frame}", text: "Mejía")

      fill_in "q", with: "zelaya"
      expect(page).to have_css(".chip-filter", text: "Búsqueda: «zelaya»")
      within("##{frame}") { expect(page).to have_no_text("Mejía") }
      expect(page).to have_field("q", with: "zelaya")
      expect(page).to have_current_path(/q=zelaya/)

      click_button "Quitar el filtro Búsqueda: «zelaya»"
      expect(page).to have_no_css(".chip-filter")
      expect(page).to have_css("##{frame}", text: "Mejía")
      expect(page_reloaded?).to be(false)
    end
  end

  it "applies a list at once and says how many there are (users, audit)" do
    create(:user, name: "Inactiva", active: false)
    visit "/administration/users"
    mark_page

    select "Inactivo", from: "status"
    expect(page).to have_text("1 resultado")
    expect(page).to have_css(".chip-filter", text: "Inactivo")

    visit "/administration/audit_events"
    mark_page
    select AuditEvent.human_attribute_name("action/create"), from: "event_action"
    expect(page).to have_css(".chip-filter", text: AuditEvent.human_attribute_name("action/create"))
    expect(page_reloaded?).to be(false)
  end
end
