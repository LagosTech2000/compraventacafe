require "rails_helper"

# Converting coffee to the next state: the gross that goes in leaves its
# state (in process) at the stock's net/gross proportion; what came out is
# weighed like a purchase (sacks, humidity, damage) and adds to the new one.
RSpec.describe CoffeeConversion do
  let(:user) { create(:user) }
  let(:wet_stock) { create(:purchase, gross_weight: 2_000) } # 973.63 net: 0.486815 a gross pound

  def convert(**attributes) = described_class.create!(from_state: "wet_parchment", weighed_at: Time.current, created_by: user,
                                                      processing_site: create(:processing_site), estimated_yield_percent: 50, **attributes)

  def finish(conversion, gross, sacks: 4, humidity: 12, damage: nil)
    conversion.assign_attributes(finished_at: Time.current, output_gross_weight: gross, output_sacks: sacks,
                                 output_humidity_percent: humidity, output_damage_percent: damage, finished_by: user)
    conversion.finishing = true
    conversion.save!
  end

  it "takes what goes in out of its state at the stock's proportion, and keeps it in process" do
    wet_stock
    conversion = convert(input_gross_weight: 1_000)

    expect(conversion).to have_attributes(to_state: "dry_parchment", number: 1, input_ratio: BigDecimal("0.486815"),
                                          input_ratio_source: "stock", input_net_weight: BigDecimal("486.82"), status: "in_process")
    stock = CoffeeStock.new
    expect(stock.row("wet_parchment")).to have_attributes(gross_stock: 1_000, stock: BigDecimal("486.81"))
    expect([ stock.in_process_gross, stock.in_process_net ]).to eq([ 1_000, BigDecimal("486.82") ])
    expect(stock.row("dry_parchment").stock).to eq(0)
  end

  it "weighs what came out like a purchase and adds it to the new state, with the net pounds it gained or lost" do
    wet_stock
    conversion = convert(input_gross_weight: 1_000)
    finish(conversion, 600) # (600 − 4 sacks) × 0.88

    expect(conversion).to have_attributes(status: "finished", output_tare: 4, output_damage_percent: 0, output_net_weight: BigDecimal("524.48"),
                                          output_ratio: BigDecimal("0.874133"), output_ratio_source: "weighed", output_weighed?: true,
                                          net_difference: BigDecimal("37.66"), net_difference_percent: BigDecimal("7.7"))
    stock = CoffeeStock.new
    expect(stock.row("dry_parchment")).to have_attributes(gross_stock: 600, stock: BigDecimal("524.48"))
    expect(stock.in_process_gross).to eq(0)

    # The next one takes the proportion of the dry parchment now in stock.
    expect(described_class.ratio_for("dry_parchment", Time.zone.today)).to eq([ BigDecimal("0.874133"), "stock" ])

    # Less net out than in: a loss.
    other = convert(input_gross_weight: 500)
    finish(other, 200, sacks: 2, damage: 2) # (200 − 2) × 0.88 × 0.98
    expect(other).to have_attributes(output_net_weight: BigDecimal("170.76"), net_difference: BigDecimal("-72.65"), net_difference_percent: BigDecimal("-29.8"))
  end

  it "takes the purchases' proportion when that state has no stock left" do
    create(:purchase, coffee_state: "dry_parchment", gross_weight: 165, humidity_percent: 12) # 144.32 net
    create(:shipment, coffee_state: "dry_parchment", origin_gross_weight: 165, origin_sacks: 1, origin_humidity_percent: 12)
    expect(described_class.ratio_for("dry_parchment", Time.zone.today)).to eq([ BigDecimal("0.874667"), "purchases" ])
    expect(described_class.ratio_for("cherry", Time.zone.today)).to eq([ BigDecimal("0.186"), "default" ])
  end

  it "voids one in process (its coffee goes back) and takes a result off (back in process)" do
    wet_stock
    conversion = convert(input_gross_weight: 1_000)
    finish(conversion, 600)
    expect { conversion.void!(user) }.to raise_error(ActiveRecord::RecordInvalid)

    conversion.reopen!
    expect(conversion.reload).to have_attributes(status: "in_process", output_gross_weight: nil, output_net_weight: nil,
                                                 output_sacks: nil, output_humidity_percent: nil, output_damage_percent: nil)
    expect(CoffeeStock.new.row("dry_parchment").stock).to eq(0)

    conversion.void!(user)
    expect(conversion.reload.status).to eq("voided")
    expect(CoffeeStock.new.row("wet_parchment")).to have_attributes(gross_stock: 2_000, stock: BigDecimal("973.63"))
  end

  it "does not finish before it was weighed, and needs what came out" do
    wet_stock
    conversion = convert(input_gross_weight: 1_000, weighed_at: Time.current)
    conversion.assign_attributes(finished_at: 1.day.ago, output_gross_weight: nil)
    conversion.finishing = true
    expect(conversion).not_to be_valid
    expect(conversion.errors.attribute_names).to include(:finished_at, :output_gross_weight, :output_sacks, :output_humidity_percent)
    expect(described_class.new(from_state: "dry_parchment", weighed_at: Time.current, input_gross_weight: 10, created_by: user)).not_to be_valid
  end

  it "puts both moves in the kardex, in gross and net pounds" do
    wet_stock
    conversion = convert(input_gross_weight: 1_000)
    finish(conversion, 600)

    ledger = StockLedger.new(from: Time.zone.today, to: Time.zone.today)
    out, came = ledger.entries.select { it.record == conversion }
    expect(out).to have_attributes(kind: "conversion_out", coffee_state: "wet_parchment", gross: -1_000, net: BigDecimal("-486.82"))
    expect(came).to have_attributes(kind: "conversion_in", coffee_state: "dry_parchment", gross: 600, net: BigDecimal("524.48"))
    expect(ledger.closing).to eq(CoffeeStock.new.stock)
    expect(ledger.gross_closing).to eq(CoffeeStock.new.gross_stock)
  end
end
