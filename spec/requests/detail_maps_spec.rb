require "rails_helper"

# The map where it was missing (Fernando, 2026-10-18): a carrero's detail
# and a person's account show where they live, when it is on the map.
RSpec.describe "Detail maps" do
  let(:person) { create(:person, first_names: "Ana", last_names: "Zelaya", latitude: 14.1, longitude: -87.2) }

  before { sign_in create(:user, :admin) }

  def map? = Nokogiri::HTML(response.body).at_css("[data-location-map-target='map']").present?

  it "shows it on the carrero and on the account" do
    get trading_hauler_path(create(:hauler, person:))
    expect(map?).to be(true)

    create(:loan, person:)
    get loans_credit_account_path(person)
    expect(map?).to be(true)
  end

  it "shows nothing without a point" do
    get trading_hauler_path(create(:hauler))
    expect(map?).to be(false)
  end
end
