require "rails_helper"

RSpec.describe PurchaseCalculation do
  def calculate(gross, humidity, price)
    described_class.new(gross_weight: gross, humidity_percent: humidity, price_per_pound: price)
  end

  it "matches the real example from the client's Excel (146 lb, 51%, L 58)" do
    result = calculate(146, 51, 58)
    expect(result.sacks).to eq(BigDecimal("0.8848"))
    expect(result.tare).to eq(1)
    expect(result.net_weight).to eq(BigDecimal("71.05"))
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
  end

  it "applies other humidity values (52–57% also appear)" do
    expect(calculate(146, 55, 58).net_weight).to eq(BigDecimal("65.25"))
  end

  it "rounds money and pounds to cents" do
    result = calculate(100.33, 51.5, 57.25)
    expect(result.net_weight).to eq(((BigDecimal("100.33") - 1) * BigDecimal("0.485")).round(2))
    expect(result.total).to eq((result.net_weight * BigDecimal("57.25")).round(2))
  end
end
