require "rails_helper"

# Netas y sacos, revisados (Fernando, 2026-11-16): the expected net (gross ×
# the usual factor) against the net calculated purchase by purchase, and why
# they differ, part by part.
RSpec.describe StockCheck do
  it "compares the expected net and sacks with the calculated ones, and its parts add up to the difference" do
    create(:purchase, coffee_state: "wet_parchment", gross_weight: 19, humidity_percent: 51, damage_percent: 0)
    create(:purchase, coffee_state: "wet_parchment", gross_weight: 1_650, humidity_percent: 51, damage_percent: 2, damage_types: %w[borer])
    create(:shipment, coffee_state: "wet_parchment", origin_gross_weight: 500, origin_sacks: 4, origin_humidity_percent: 51, origin_damage_percent: 0)

    check = described_class.new
    row = check.row("wet_parchment")
    expect(row.gross).to eq(1_169)
    expect(row.expected_net).to eq((1_169 * 0.49).round(2))
    expect(row.net).to eq(CoffeeStock.new.row("wet_parchment").stock)
    expect(row.expected_sacks).to eq(7) # 1,169 ÷ 165 = 7.08, whole sacks

    parts = check.explanation("wet_parchment")
    expect(parts.map(&:key)).to eq(%i[purchases shipments])
    expect(parts.sum(&:effect)).to be_within(0.02).of(row.difference)

    breakdown = check.purchases_breakdown("wet_parchment")
    expect(breakdown[:tare]).to eq(11)
    expect(breakdown[:damage]).to be_positive
    expect(breakdown[:tare_effect] + breakdown[:damage_effect] + breakdown[:other_effect]).to eq(breakdown[:total])
    expect(parts.first.effect).to eq(breakdown[:total])
  end

  it "uses the cherry's yield as its factor" do
    expect(described_class.factor("cherry")).to eq(PurchaseDefaults::CHERRY_YIELD)
    expect(described_class.factor("dry_parchment")).to eq(0.88)
  end
end
