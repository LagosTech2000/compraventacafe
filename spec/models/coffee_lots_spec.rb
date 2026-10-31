require "rails_helper"

# The stock lot by lot (client, 2026-10-26): coffee leaves the oldest lots
# first, in net pounds; sacks, damage and value go with the share taken;
# transfers keep each lot's date; a conversion's result is a lot with the
# value of what went in.
RSpec.describe CoffeeLots do
  let(:main) { Warehouse.main! }
  let(:other) { create(:warehouse, name: "Bodega 2") }
  # 2,000 lb gross: (2,000 − 13) × 0.49 = 973.63 net, at L 58 = L 56,470.54.
  let!(:older) { create(:purchase, gross_weight: 2_000, purchased_at: 2.days.ago) }
  # 1,000 lb gross: (1,000 − 7) × 0.49 = 486.57 net.
  let!(:newer) { create(:purchase, gross_weight: 1_000, purchased_at: 1.day.ago) }

  def lots(**filters) = described_class.new.lots(coffee_state: "wet_parchment", **filters)

  it "puts every purchase into the default warehouse, as a lot with its value" do
    expect([ older, newer ].map(&:warehouse)).to all(eq(main))
    expect(lots.map(&:source)).to eq([ older, newer ])
    expect(lots.first).to have_attributes(net: older.net_weight, net_in: older.net_weight, sacks: older.sacks, purchase_value: older.total, costs: 0)
  end

  it "takes a shipment from the oldest lot first, with its share of sacks and value" do
    shipment = create(:shipment) # 487.06 net
    engine = described_class.new
    left = engine.lots(coffee_state: "wet_parchment")
    taken = engine.portions_for(shipment)

    expect(taken.map(&:lot).map(&:source)).to eq([ older ])
    expect(left.map { [ it.source, it.net ] }).to eq([ [ older, BigDecimal("486.57") ], [ newer, newer.net_weight ] ])
    expect(left.first.sacks + taken.first.sacks).to be_within(0.001).of(older.sacks)
    expect(left.first.purchase_value + taken.first.purchase_value).to eq(older.total)
    expect(engine.totals(left).net).to eq(CoffeeStock.new.row("wet_parchment").stock)
  end

  it "goes on to the next lot, and leaves a shortfall when there is not enough" do
    shipment = create(:shipment, origin_gross_weight: 4_000, origin_sacks: 20) # (4,000 − 20) × 0.49 = 1,950.20
    taken = described_class.new.portions_for(shipment)

    expect(taken.map { it.lot&.source }).to eq([ older, newer, nil ])
    expect(taken.last).to have_attributes(shortfall?: true, net: BigDecimal("1950.20") - older.net_weight - newer.net_weight)
    expect(lots).to be_empty
  end

  it "frees the lots again when the shipment is voided" do
    shipment = create(:shipment)
    shipment.void!(create(:user))

    expect(lots.sum(&:net)).to eq(older.net_weight + newer.net_weight)
  end

  it "moves the oldest lots to the other warehouse, keeping their date" do
    # Written in gross pounds (client, 2026-10-30): 2,054.52 × 0.486733 (the
    # warehouse's 1,460.20 net ÷ 3,000 gross) = 1,000 net.
    transfer = create(:warehouse_transfer, from_warehouse: main, to_warehouse: other, gross_weight: 2_054.52)
    expect(transfer.net_weight).to eq(1_000)

    expect(lots(warehouse_id: other.id).map { [ it.source, it.entered_at.to_i, it.net, it.transfer ] })
      .to eq([ [ older, older.purchased_at.to_i, older.net_weight, transfer ], [ newer, newer.purchased_at.to_i, BigDecimal("26.37"), transfer ] ])
    expect(lots(warehouse_id: main.id).map { [ it.source, it.net ] }).to eq([ [ newer, BigDecimal("460.20") ] ])
    expect(CoffeeStock.new(warehouse: other).row("wet_parchment").stock).to eq(1_000)
    expect(CoffeeStock.new(warehouse: main).row("wet_parchment").stock).to eq(BigDecimal("460.20"))
    expect(CoffeeStock.new.row("wet_parchment").stock).to eq(older.net_weight + newer.net_weight)
  end

  it "makes a conversion's result a lot worth what went in, in the warehouse chosen" do
    conversion = create(:coffee_conversion, :finished, from_state: "wet_parchment", input_gross_weight: 2_500, weighed_at: 3.hours.ago, warehouse: main,
                                                       output_warehouse: other, output_humidity_percent: 12)
    engine = described_class.new
    went_in = engine.portions_for(conversion)
    result = engine.lots(coffee_state: "dry_parchment").sole

    expect(went_in.map { it.lot.source }).to eq([ older, newer ])
    expect(result).to have_attributes(source: conversion, warehouse_id: other.id, net: conversion.output_net_weight, sacks: 4,
                                      purchase_value: went_in.sum(&:purchase_value))
  end

  it "adds the hauler's commission to the value of its purchase" do
    hauled = create(:purchase, gross_weight: 1_000, hauler: create(:hauler, price_per_pound: 0.5))

    lot = lots.find { it.source == hauled }
    expect(lot).to have_attributes(costs: hauled.hauler_commission, value: hauled.total + hauled.hauler_commission)
  end
end
