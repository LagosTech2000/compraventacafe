require "rails_helper"

# «QQ sobrantes» in Comercialización: Resumen (today and the season), the
# list of sales and the daily close.
RSpec.describe "QQ sobrantes" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)

  it "shows them under the sales' figures" do
    create(:sale).update_columns(origin_net_weight: 12_500, net_weight: 12_500, quintal_pounds: 100, unit_price: 5_000, price_unit: "quintal",
                                 total: 625_000, sold_on: Time.zone.today)
    sign_in admin

    get sales_root_path
    season = page.at_css("[data-quintal-gain=season]")
    expect(season.at_css("[data-gain=quintals] dd").text.strip).to eq("+25.00")
    expect(season.at_css("[data-gain=quintals]").text).to include("25 % más")
    expect(season.at_css("[data-gain-part=size]").text).to include("L 125,000.00")

    get sales_sales_path
    expect(page.at_css("[data-quintal-gain=list]")).to be_present
    get sales_daily_close_path(date: Time.zone.today)
    expect(page.at_css("[data-quintal-gain=close]")).to be_present
  end
end
