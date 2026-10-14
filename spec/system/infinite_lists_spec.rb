require "rails_helper"

# Every list loads its next page while scrolling (shared/_pagination,
# infinite_list_controller.js), also the ones that are not in a frame.
RSpec.describe "Infinite lists", type: :system do
  let(:user) { create(:user, :admin) }

  it "adds the next zones at the end of the list, once each" do
    (ListFilter::PER_PAGE + 3).times { |index| create(:zone, name: format("Zona %03d", index)) }
    sign_in_as(user)
    visit trading_zones_path
    expect(page).to have_css("tbody tr[id^=zone_]", count: ListFilter::PER_PAGE)
    page.execute_script("window.pageMarker = 'still here'")

    find("button", text: "Cargar más").execute_script("this.scrollIntoView()")
    expect(page).to have_css("tbody tr[id^=zone_]", count: ListFilter::PER_PAGE + 3)
    expect(page).to have_no_button("Cargar más")
    expect(page.evaluate_script("window.pageMarker")).to eq("still here")
    ids = all("tbody tr[id^=zone_]").map { it[:id] }
    expect(ids.uniq.size).to eq(ids.size)
  end
end
