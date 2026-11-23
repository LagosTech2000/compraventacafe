require "rails_helper"

# Nothing takes more coffee than there is, once that state and warehouse were
# counted (Fernando, 2026-11-18); before the first count it only warns.
RSpec.describe StockGuard, :all_records do
  let(:admin) { create(:user, :admin) }
  let(:warehouse) { Warehouse.main! }

  before { create(:purchase, gross_weight: 1_000, purchased_at: 3.days.ago) }

  def net_stock = CoffeeStock.new(warehouse:).row("wet_parchment").stock

  it "lets anything out before the first count" do
    expect(build(:warehouse_transfer, gross_weight: 5_000)).to be_valid
    expect(build(:shipment, origin_gross_weight: 5_000, origin_sacks: 30)).to be_valid
  end

  it "stops a transfer, a shipment and a process over the stock once counted" do
    create(:stock_count, counted_at: 2.days.ago)

    transfer = build(:warehouse_transfer, gross_weight: 5_000)
    expect(transfer).not_to be_valid
    expect(transfer.errors.full_messages.join).to include("no puede salir más de lo que hay")
    expect(build(:warehouse_transfer, gross_weight: 100)).to be_valid

    shipment = build(:shipment, origin_gross_weight: 5_000, origin_sacks: 30)
    expect(shipment).not_to be_valid
    expect(build(:shipment, origin_gross_weight: 500, origin_sacks: 3)).to be_valid

    conversion = build(:coffee_conversion, from_state: "wet_parchment", input_gross_weight: 5_000)
    expect(conversion).not_to be_valid
    expect(conversion.errors.full_messages.join).to include("no puede salir más de lo que hay")
  end

  # Processing cherry is checked in gross pounds (Fernando, 2026-11-22).
  it "checks a cherry process against the gross pounds" do
    create(:purchase, coffee_state: "cherry", gross_weight: 1_000, purchased_at: 3.days.ago)
    create(:stock_count, coffee_state: "cherry", counted_at: 2.days.ago)

    conversion = build(:coffee_conversion, from_state: "cherry", input_gross_weight: 1_200)
    expect(conversion).not_to be_valid
    expect(conversion.errors.full_messages.join).to include("Solo hay 1,000.00 lb brutas de Uva", "esto procesa 1,200.00")
    expect(build(:coffee_conversion, from_state: "cherry", input_gross_weight: 1_000)).to be_valid
  end

  it "does not let a move dated back take what later moves already took" do
    create(:stock_count, counted_at: 2.days.ago)
    create(:shipment, origin_gross_weight: 900, origin_sacks: 6, departed_at: 1.hour.ago)
    expect(net_stock).to be < 100

    expect(build(:shipment, origin_gross_weight: 500, origin_sacks: 3, departed_at: 1.day.ago)).not_to be_valid
  end

  it "counts what the record itself took when it is saved again" do
    create(:stock_count, counted_at: 2.days.ago)
    shipment = create(:shipment, origin_gross_weight: 900, origin_sacks: 6, departed_at: 1.hour.ago)
    expect(shipment.update(origin_gross_weight: 950)).to be(true)
    expect(shipment.update(origin_gross_weight: 2_000, origin_sacks: 12)).to be(false)
  end

  it "holds only from the count's moment on" do
    create(:stock_count, counted_at: 1.hour.ago)
    expect(build(:warehouse_transfer, gross_weight: 5_000, transferred_at: 2.hours.ago)).to be_valid
  end
end
