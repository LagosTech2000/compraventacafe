require "rails_helper"

# Physical counts and their adjustment (Fernando, 2026-11-18): the stock is
# left as counted, in every place that reads it.
RSpec.describe StockCount, :all_records do
  let(:admin) { create(:user, :admin) }
  let(:clerk) { create(:user) }
  let(:warehouse) { Warehouse.main! }
  let!(:purchase) { create(:purchase, gross_weight: 1_000, purchased_at: 2.days.ago) }

  def count!(gross, by: admin, **options)
    StockCount.create!(warehouse:, coffee_state: "wet_parchment", counted_at: 1.hour.ago, counted_gross: gross, created_by: by, **options)
  end

  it "keeps what the system said and adjusts the stock to what was counted" do
    stock = CoffeeStock.new(warehouse:).row("wet_parchment")
    count = count!(900, reason: "drying")

    expect(count).to have_attributes(system_gross: stock.gross_stock.round(2), system_net: stock.stock.round(2), gross_weight: -100)
    expect(count.net_weight).to eq((900 * stock.stock / stock.gross_stock).round(2) - stock.stock.round(2))
    after = CoffeeStock.new(warehouse:).row("wet_parchment")
    expect(after.gross_stock).to eq(900)
    expect(after.stock).to be_within(0.01).of(900 * stock.stock / stock.gross_stock)
    expect(count.difference_percent).to eq(-10)
  end

  # A count of 0 leaves no net pounds (Fernando, 2026-11-22: uva stayed at
  # −0.05 lb netas of the old processes' rounding).
  it "leaves no net pounds when nothing was counted, without a reason when the system had nothing either" do
    process = create(:coffee_conversion, from_state: "wet_parchment", warehouse:, weighed_at: 1.day.ago, input_gross_weight: 1_000)
    process.update_columns(input_net_weight: process.input_net_weight + 0.05)
    expect(CoffeeStock.new(warehouse:).row("wet_parchment").stock.round(2)).to eq(-0.05)

    count = StockCount.create!(warehouse:, coffee_state: "wet_parchment", counted_at: 1.hour.ago, counted_gross: 0, created_by: clerk)
    expect(count).to have_attributes(gross_weight: 0, net_weight: 0.05, reason: nil)
    expect(count).not_to be_difference
    expect(CoffeeStock.new(warehouse:).row("wet_parchment").stock).to eq(0)
  end

  it "needs a reason with a difference, and its detail when it is «Otro»" do
    expect { count!(950) }.to raise_error(ActiveRecord::RecordInvalid, /Motivo de la diferencia es obligatorio/)
    expect { count!(950, reason: "other") }.to raise_error(ActiveRecord::RecordInvalid, /Detalle del motivo es obligatorio/)
    expect(count!(1_000)).to have_attributes(gross_weight: 0, net_weight: 0, reason: nil)
  end

  it "leaves an adjustment over the share of the site settings to an administrator" do
    expect { count!(950, by: clerk, reason: "loss") }.to raise_error(ActiveRecord::RecordInvalid, /solo un administrador/)
    expect(count!(990, by: clerk, reason: "scale_error").gross_weight).to eq(-10)
    expect(count!(900, reason: "loss").gross_weight).to eq(-90)
  end

  it "takes a shortage from the oldest lots, as a loss, and brings a surplus in as a lot with no cost" do
    newer = create(:purchase, gross_weight: 500, purchased_at: 1.day.ago)
    shortage = count!(1_400, reason: "loss")
    portions = CoffeeLots.new.portions_for(shortage)
    expect(portions.map { it.lot.source }).to eq([ purchase ])
    expect(portions.sum(0.to_d, &:value)).to be_positive

    surplus = StockCount.create!(warehouse:, coffee_state: "wet_parchment", counted_at: Time.current, counted_gross: 1_450, reason: "surplus", created_by: admin)
    lot = CoffeeLots.new.lots(coffee_state: "wet_parchment").find(&:count?)
    expect(lot.source).to eq(surplus)
    expect(lot.value).to eq(0)
    expect(CoffeeLots.new.lots(coffee_state: "wet_parchment").map(&:source)).to include(newer)
  end

  it "is a move of the kardex and of the net check" do
    count = count!(900, reason: "drying")
    entry = StockLedger.new(from: Time.zone.today - 3, to: Time.zone.today, warehouse:).entries.find { it.kind == "adjustment" }
    expect(entry.record).to eq(count)
    expect(entry.gross).to eq(-100)
    part = StockCheck.new(warehouse:).explanation("wet_parchment").find { it.key == :counts }
    expect(part.gross).to eq(-100)
  end

  it "goes after the last count of its state and warehouse, and is voided only while none was made on it" do
    first = count!(900, reason: "drying")
    expect { count!(800, reason: "drying", counted_at: 2.hours.ago) }.to raise_error(ActiveRecord::RecordInvalid, /antes del último conteo/)
    second = StockCount.create!(warehouse:, coffee_state: "wet_parchment", counted_at: Time.current, counted_gross: 900, created_by: admin)

    expect { first.void!(admin, reason: "Mal contado") }.to raise_error(ActiveRecord::RecordInvalid, /conteo #{second.display_number}/)
    second.void!(admin, reason: "Repetido")
    first.void!(admin, reason: "Mal contado")
    expect(CoffeeStock.new(warehouse:).row("wet_parchment").gross_stock).to eq(1_000)
  end
end
