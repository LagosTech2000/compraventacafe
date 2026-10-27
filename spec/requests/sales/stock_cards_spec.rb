require "rails_helper"

# «Café en inventario» (client, 2026-10-26): each card shows its net pounds,
# always; a click opens the rest: gross pounds, quintals, sacks, damage
# applied and the value of the coffee left.
RSpec.describe "Coffee in stock cards" do
  def page = Nokogiri::HTML(response.body)

  before do
    create(:purchase, gross_weight: 2_000, damage_percent: 2) # (2,000 − 13) × 0.49 × 0.98 = 954.16 net; damage 19.47 lb
    sign_in create(:user, :admin)
  end

  it "shows only the net pounds on each card" do
    get sales_stock_path

    %w[total cherry wet_parchment dry_parchment].each do |key|
      card = page.at_css("[data-coffee-state=#{key}]")
      expect(card.at_css("[data-live-value]")).to be_present, key
      expect(card.text).to include("Libras netas"), key
      expect(card.text).not_to include("Libras brutas"), key
    end
    expect(page.at_css("[data-coffee-state=wet_parchment] [data-live-value]").text.squish).to eq("954.16 lb")
  end

  it "shows the rest in the card's detail" do
    purchase = Purchase.sole
    get sales_stock_state_path("wet_parchment")

    figures = page.at_css("#state-figures").parent.text.squish
    expect(figures).to include("954.16 lb", "Libras brutas2,000.00 lb", "QQ de compra7.63", "Sacos12", "Daño aplicado19.47 lb")
    expect(page.at_css("[data-stock-value]").text.squish).to include("Valor de compraL #{ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", purchase.total))}")

    get sales_stock_state_path("cherry")
    expect(page.at_css("[data-cherry-net-note]").text).to include("el café que se espera sacar")
  end
end
