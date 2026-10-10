require "rails_helper"

RSpec.describe PurchaseCalculation do
  def calculate(gross, humidity, price, damage: 0, state: "wet_parchment")
    described_class.new(coffee_state: state, gross_weight: gross, humidity_percent: humidity, damage_percent: damage, price_per_pound: price)
  end

  def cherry(gross, yield_factor, price)
    described_class.new(coffee_state: "cherry", gross_weight: gross, yield_factor:, price_per_pound: price)
  end

  it "matches the real example from the client's Excel (146 lb, 51%, L 58)" do
    result = calculate(146, 51, 58)
    expect(result.sacks).to eq(BigDecimal("0.8848"))
    expect(result.tare).to eq(1)
    expect(result.net_weight).to eq(BigDecimal("71.05"))
    expect(result.quintals).to eq(BigDecimal("0.57"))
    expect(result.total).to eq(BigDecimal("4120.90"))
  end

  it "charges 1 lb of tare per started 165 lb sack" do
    expect(calculate(165, 0, 1).tare).to eq(1)
    expect(calculate(166, 0, 1).tare).to eq(2)
    expect(calculate(330, 0, 1).tare).to eq(2)
    expect(calculate(331, 0, 1).tare).to eq(3)
  end

  it "never gives a negative net weight" do
    expect(calculate(0.5, 51, 58).net_weight).to eq(0)
    expect(calculate(0.5, 51, 58).total).to eq(0)
    expect(cherry(0.5, 0.186, 58).net_weight).to eq(0)
  end

  it "applies other humidity values (52–57% also appear)" do
    expect(calculate(146, 55, 58).net_weight).to eq(BigDecimal("65.25"))
  end

  it "calculates dry parchment like wet parchment, with its own humidity" do
    expect(calculate(146, 12, 58, state: "dry_parchment").net_weight).to eq(BigDecimal("127.60"))
  end

  it "takes the damage percentage off the net weight in parchment" do
    # (146 − 1) × 0.49 = 71.05; minus 2.5% of damage = 69.27
    result = calculate(146, 51, 58, damage: 2.5)
    expect(result.net_weight).to eq(BigDecimal("69.27"))
    expect(result.damage_weight).to eq(BigDecimal("1.78"))
    expect(calculate(146, 51, 58).damage_weight).to eq(0)
    expect(cherry(146, 0.186, 58).damage_weight).to be_nil
    expect(result.total).to eq(BigDecimal("4017.66"))
  end

  it "calculates cherry with the yield instead of humidity: (gross − tare) × yield" do
    # (1000 − 7) × 0.186 = 184.70 lb; 184.70 / 125 = 1.48 QQ
    result = cherry(1000, 0.186, 10)
    expect(result.tare).to eq(7)
    expect(result.net_weight).to eq(BigDecimal("184.70"))
    expect(result.quintals).to eq(BigDecimal("1.48"))
    expect(result.total).to eq(BigDecimal("1847.00"))
  end

  it "expresses the net weight in quintals of 125 lb" do
    expect(described_class.quintals(250)).to eq(2)
    expect(described_class.quintals(BigDecimal("71.05"))).to eq(BigDecimal("0.57"))
  end

  it "rounds money and pounds to cents" do
    result = calculate(100.33, 51.5, 57.25)
    expect(result.net_weight).to eq(((BigDecimal("100.33") - 1) * BigDecimal("0.485")).round(2))
    expect(result.total).to eq((result.net_weight * BigDecimal("57.25")).round(2))
  end
end
