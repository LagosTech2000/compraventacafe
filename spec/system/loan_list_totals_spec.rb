require "rails_helper"

# Préstamos (Fernando, 2026-11-12): choosing a zone filters in place and the
# totals of what is filtered appear, without reloading the page.
RSpec.describe "Loans list totals", type: :system do
  it "filters by zone and shows the totals in place" do
    zone = create(:zone, name: "Morocelí")
    create(:loan, person: create(:person, first_names: "Ana", last_names: "Zelaya", zone:), cash_amount: 1_000, monthly_interest_rate: 0)
    create(:loan, person: create(:person, first_names: "Beto", last_names: "Lara"), cash_amount: 500, monthly_interest_rate: 0)
    sign_in_as(create(:user, :admin))
    visit loans_loans_path
    expect(page).to have_no_css("[data-loan-totals]")
    page.execute_script("document.body.dataset.pageMarker = 'still here'")

    select "Morocelí", from: "Zona"
    within("[data-loan-totals]") { expect(page).to have_css("[data-total='principal'] dd", text: "L 1,000.00") }
    expect(page).to have_no_text("Beto Lara")
    expect(page).to have_link("Imprimir", href: /zone_id=#{zone.id}/)
    expect(page.evaluate_script("document.body.dataset.pageMarker")).to eq("still here")
  end
end
