require "rails_helper"

RSpec.describe CoffeeStock do
  it "adds the net of active purchases and takes the origin net of shipments not voided, by coffee state" do
    create(:purchase, gross_weight: 2_000)                         # (2,000 − 13) × 0.49 = 973.63
    create(:purchase, gross_weight: 2_000, voided_at: Time.current)
    create(:purchase, coffee_state: "dry_parchment", gross_weight: 165, humidity_percent: 12) # (165 − 1) × 0.88 = 144.32
    create(:shipment)                                              # 487.06 in transit
    create(:shipment, voided_at: Time.current)
    create(:shipment, :received, departed_at: 1.day.ago)           # 487.06 out, 482.16 at the buyer's, unsold

    stock = described_class.new
    wet = stock.row("wet_parchment")
    expect(wet).to have_attributes(purchased: BigDecimal("973.63"), shipped: BigDecimal("974.12"),
                                   in_transit: BigDecimal("487.06"), unsold: BigDecimal("482.16"))
    expect(wet.stock).to eq(BigDecimal("-0.49"))
    expect(stock.row("dry_parchment").stock).to eq(BigDecimal("144.32"))
    expect(stock.row("cherry").stock).to eq(0)
  end

  it "counts gross pounds the same way: the purchases' gross minus the shipments' local gross" do
    create(:purchase, gross_weight: 2_000)
    create(:purchase, gross_weight: 2_000, voided_at: Time.current)
    create(:purchase, coffee_state: "dry_parchment", gross_weight: 165, humidity_percent: 12)
    create(:shipment, origin_gross_weight: 700)
    create(:shipment, origin_gross_weight: 500, voided_at: Time.current)

    stock = described_class.new
    expect(stock.row("wet_parchment")).to have_attributes(gross_purchased: 2_000, gross_shipped: 700, gross_stock: 1_300)
    expect(stock.row("dry_parchment").gross_stock).to eq(165)
    expect(stock.gross_stock).to eq(1_465)
  end

  it "counts up to the end of a day" do
    create(:purchase, gross_weight: 2_000, purchased_at: 2.days.ago)
    create(:shipment, departed_at: Time.current)
    expect(described_class.new(Time.zone.yesterday).stock).to eq(BigDecimal("973.63"))
    expect(described_class.new.stock).to eq(BigDecimal("486.57"))
  end

  it "lists the kardex with the balance after each entry" do
    create(:purchase, gross_weight: 2_000, purchased_at: 3.days.ago)
    create(:purchase, gross_weight: 1_000, purchased_at: 1.day.ago) # (1,000 − 7) × 0.49 = 486.57
    create(:shipment, departed_at: Time.current)
    ledger = StockLedger.new(from: 2.days.ago.to_date, to: Time.zone.today)
    expect(ledger.opening).to eq(BigDecimal("973.63"))
    expect(ledger.entries.map(&:balance)).to eq([ BigDecimal("1460.20"), BigDecimal("973.14") ])
    expect(ledger.closing).to eq(BigDecimal("973.14"))
  end
end
