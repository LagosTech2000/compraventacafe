require "rails_helper"

RSpec.describe Shipment do
  it "calculates each scale's net like a purchase with the sacks counted" do
    shipment = create(:shipment, origin_gross_weight: 1_000, origin_sacks: 6, origin_humidity_percent: 51, origin_damage_percent: 2)
    # (1,000 − 6) × 0.49 × 0.98
    expect(shipment).to have_attributes(origin_tare: 6, origin_net_weight: BigDecimal("477.32"), number: 1, season_year: Season.current.year)

    cherry = create(:shipment, coffee_state: "cherry", origin_gross_weight: 1_000, origin_sacks: 10, origin_yield_factor: 0.186)
    expect(cherry.origin_net_weight).to eq(BigDecimal("184.14")) # (1,000 − 10) × 0.186
    expect(cherry.number).to eq(2)
  end

  it "keeps its weights when nothing they come from changes" do
    shipment = create(:shipment)
    shipment.update_columns(origin_net_weight: 1)
    shipment.update!(remission_number: "330")
    expect(shipment.reload.origin_net_weight).to eq(1)
  end

  it "needs the whole destination weighing once it is received, not before the day it left" do
    shipment = create(:shipment, departed_at: Time.zone.local(2026, 10, 20, 8))
    shipment.receiving = true
    expect(shipment).not_to be_valid
    expect(shipment.errors).to include(:received_on, :destination_gross_weight)

    shipment.assign_attributes(received_on: Date.new(2026, 10, 19), destination_gross_weight: 980, destination_sacks: 6,
                               destination_humidity_percent: 51)
    expect(shipment).not_to be_valid
    expect(shipment.errors[:received_on]).to be_present
  end

  it "compares the buyer's scale with the local one, against the site's tolerance" do
    shipment = create(:shipment, :received) # 487.06 local, (990 − 6) × 0.49 = 482.16 at destination
    expect(shipment.net_difference).to eq(BigDecimal("-4.90"))
    expect(shipment.difference_percent).to eq(BigDecimal("-1.01"))
    expect(shipment).not_to be_over_tolerance
    expect(shipment.over_tolerance?(1)).to be(true)
    expect(shipment.over_tolerance?(2)).to be(false)
  end

  it "goes in transit → received → sold, or voided" do
    shipment = create(:shipment)
    expect(shipment.status).to eq("in_transit")
    shipment.update!(received_on: Time.zone.today, destination_gross_weight: 990, destination_sacks: 6, destination_humidity_percent: 51)
    expect(shipment.status).to eq("received")
    expect(Shipment.unsold).to include(shipment)
    create(:sale, buyer: shipment.buyer, shipments: [ shipment ])
    expect(shipment.reload.status).to eq("sold")
    expect(Shipment.unsold).not_to include(shipment)
    expect(shipment.update(origin_gross_weight: 1_200)).to be(false)
    expect(shipment.reload.update(remission_number: "331")).to be(true)
  end
end
