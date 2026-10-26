require "rails_helper"

# «Café en inventario»: each card says gross pounds, net pounds and quintals,
# in that order, for the whole stock and for each coffee state.
RSpec.describe "Coffee in stock cards" do
  before do
    create(:purchase, gross_weight: 2_000) # (2,000 − 13) × 0.49 = 973.63 net
    sign_in create(:user, :admin)
  end

  it "shows gross, net and quintals in that order for cherry, wet and dry parchment" do
    get sales_stock_path
    page = Nokogiri::HTML(response.body)

    %w[total cherry wet_parchment dry_parchment].each do |key|
      card = page.at_css("[data-coffee-state=#{key}]")
      expect(card.css("[data-stock-part]").map { it["data-stock-part"] }).to eq(%w[gross net quintals]), key
      expect(card.css("dt").map(&:text)).to eq([ "Libras brutas", "Libras netas", "Quintales" ])
    end
    wet = page.at_css("[data-coffee-state=wet_parchment]")
    expect(wet.css("dd").map { it.text.squish }).to eq([ "2,000.00 lb", "973.63 lb", "7.79" ])
  end
end
