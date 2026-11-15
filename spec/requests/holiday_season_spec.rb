require "rails_helper"

# Small Christmas decorations only while the season lasts (Fernando,
# 2026-11-15): the lights on the navigation and the little tree with
# «¡Felices fiestas!» on the Inicio and the sign-in page.
RSpec.describe "Christmas decorations" do
  include ActiveSupport::Testing::TimeHelpers

  def page = Nokogiri::HTML(response.body)

  it "shows them in the season and not after" do
    travel_to Time.zone.local(2026, 12, 20, 10) do
      get new_session_path
      expect(page.at_css("body")["class"]).to include("christmas")
      expect(page.at_css("[data-holiday]").text).to eq("¡Felices fiestas!")

      sign_in create(:user, :admin)
      get root_path
      expect(page.at_css("nav.holiday-garland")).to be_present
      expect(page.at_css("[data-holiday]").text).to eq("¡Felices fiestas!")

      get new_trading_purchase_path
      expect(page.at_css("form.holiday-frame")).to be_present
    end

    travel_to Time.zone.local(2027, 2, 3, 10) do
      get root_path
      expect(page.at_css("body")["class"]).not_to include("christmas")
      expect(page.at_css("[data-holiday]")).to be_nil
      get new_trading_purchase_path
      expect(page.at_css(".holiday-frame")).to be_nil
    end
  end
end
