require "rails_helper"

# QQ sobrantes (Fernando, 2026-11-16): the coffee sold in purchase quintals
# (÷ 125) against sale quintals, split by the quintal's size and the weight,
# each in money at the sale's price.
RSpec.describe SaleSummary do
  def sale(local:, buyer:, quintal_pounds:, unit_price:, price_unit: "quintal")
    create(:sale).tap do
      it.update_columns(origin_net_weight: local, net_weight: buyer, quintal_pounds:, unit_price:, price_unit:,
                        total: Sale.amount_for(buyer, unit_price:, price_unit:, quintal_pounds:))
    end
  end

  it "counts the extra quintals of selling in 100 lb quintals: 25 % more, plus the weight the buyer added" do
    sale(local: 12_500, buyer: 12_600, quintal_pounds: 100, unit_price: 5_000)
    gain = described_class.new(Sale.all).quintal_gain

    expect(gain.purchase_quintals).to eq(100)
    expect(gain.sale_quintals).to eq(126)
    expect(gain.size_quintals).to eq(25)
    expect(gain.weight_quintals).to eq(1)
    expect(gain.quintals).to eq(26)
    expect(gain.percent).to eq(26)
    expect(gain.pounds).to eq(100)
    expect(gain.size_amount).to eq(125_000)
    expect(gain.weight_amount).to eq(5_000)
    expect(gain.at_purchase_quintals).to eq(gain.total - 130_000)
  end

  it "uses each sale's own quintal and price per pound, and leaves out sales without the local scale" do
    sale(local: 12_000, buyer: 12_000, quintal_pounds: 120, unit_price: 50, price_unit: "pound")
    sale(local: 1_000, buyer: 1_000, quintal_pounds: 100, unit_price: 40, price_unit: "pound").update_columns(origin_net_weight: nil)
    gain = described_class.new(Sale.all).quintal_gain

    expect(gain.sales_count).to eq(1)
    expect(gain.left_out).to eq(1)
    expect(gain.size_quintals).to eq((100 - 96).to_d)
    expect(gain.size_amount).to eq((12_000 * (1 - (120 / 125.0)) * 50).round(2))
    expect(gain.weight_amount).to eq(0)
  end
end
