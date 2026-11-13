require "rails_helper"

# The Inicio's «Productores que no venden hace…» (Fernando, 2026-11-13):
# changing the days reloads only the card; «Ver todos» opens the whole list.
RSpec.describe "Producers that stopped selling", type: :system do
  let(:admin) { create(:user, :admin) }

  it "changes the days in place and opens the whole list in a window" do
    create(:purchase, producer: create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")), purchased_at: 10.days.ago)
    create(:purchase, producer: create(:producer, person: create(:person, first_names: "Bruno", last_names: "Lara")), purchased_at: 40.days.ago)
    sign_in_as(admin)
    page.execute_script("document.body.dataset.pageMarker = 'still here'")

    within("turbo-frame#idle-producers") do
      expect(page).to have_text("Ana Zelaya")
      expect(page).to have_text("Bruno Lara")
      select "un mes", from: "idle_producers_days"
      expect(page).to have_css("[data-idle-producers='30']")
      expect(page).to have_no_text("Ana Zelaya")
      expect(page).to have_text("Bruno Lara")
    end
    expect(page.evaluate_script("document.body.dataset.pageMarker")).to eq("still here")

    within("turbo-frame#idle-producers") { click_link "Ver todos" }
    within("dialog[open]") do
      expect(page).to have_css("h1", text: "Productores que no venden")
      expect(page).to have_css("table tbody tr", count: 1, text: "Bruno Lara")
    end
  end
end
