require "rails_helper"

# A producer's quintals of the season are the base of the retention and
# «café corriente» does not add to them: it is its own figure, also per
# season (Fernando, 2026-11-12).
RSpec.describe "Producer quintals without café corriente" do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer) }

  def page = Nokogiri::HTML(response.body)
  def quintals_of(*purchases) = format("%.2f", PurchaseCalculation.quintals(purchases.sum(&:net_weight)))

  let!(:regular) { create(:purchase, producer:, gross_weight: 1_000) }
  let!(:common) { create(:purchase, producer:, gross_weight: 500, common_coffee: true) }

  before { sign_in admin }

  it "keeps café corriente out of the producer's season quintals and shows it apart" do
    profile = ProducerProfile.new(producer)
    expect(profile.season_quintals).to eq(PurchaseCalculation.quintals(regular.net_weight))
    expect(profile.season_common_quintals).to eq(PurchaseCalculation.quintals(common.net_weight))
    row = profile.seasons.first
    expect([ row.quintals, row.common_quintals ]).to eq([ profile.season_quintals, profile.season_common_quintals ])

    get trading_producer_path(producer)
    expect(response.body).to include("QQ de café corriente", quintals_of(common))
  end

  it "shows both in the producers list and in the producer's card of «Nueva compra»" do
    get trading_producers_path
    row = page.at_css("tr#producer_#{producer.id}")
    expect(row.text).to include(quintals_of(regular))
    expect(row.at_css("[data-common-quintals]").text.strip).to eq(quintals_of(common))

    get trading_producer_card_path(producer)
    expect(page.at_css("[data-common-quintals]").text).to include(quintals_of(common))
  end

  it "keeps it apart in the producers report" do
    get reports_report_path("producers", period: "all")
    expect(response).to have_http_status(:ok)
    headers = page.css("table thead th").map { it.text.squish }
    cells = page.css("table tbody tr").find { it.text.include?(producer.full_name) }.css("td").map { it.text.strip }
    expect(cells[headers.index { it.start_with?("QQ") }]).to include(quintals_of(regular))
    expect(cells[headers.index { it.start_with?("Café corriente") }]).to include(quintals_of(common))
  end
end
