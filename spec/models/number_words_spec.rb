require "rails_helper"

RSpec.describe NumberWords do
  it "writes amounts in lempiras, with the short forms before a noun" do
    {
      0 => "cero lempiras exactos",
      1 => "un lempiras exactos",
      21 => "veintiún lempiras exactos",
      31 => "treinta y un lempiras exactos",
      100 => "cien lempiras exactos",
      115 => "ciento quince lempiras exactos",
      1_000 => "mil lempiras exactos",
      1_500 => "mil quinientos lempiras exactos",
      21_000 => "veintiún mil lempiras exactos",
      100_000 => "cien mil lempiras exactos",
      1_000_000 => "un millón lempiras exactos",
      2_516_000 => "dos millones quinientos dieciséis mil lempiras exactos"
    }.each { |amount, words| expect(described_class.amount(amount)).to eq(words) }
  end

  it "adds the cents as a fraction of 100" do
    expect(described_class.amount(1_521.5)).to eq("mil quinientos veintiún lempiras con 50/100")
    expect(described_class.amount(BigDecimal("10.05"))).to eq("diez lempiras con 05/100")
  end

  it "reads rates with decimals" do
    expect(described_class.decimal(5)).to eq("cinco")
    expect(described_class.decimal(BigDecimal("3.00"))).to eq("tres")
    expect(described_class.decimal(2.5)).to eq("dos punto cinco")
    expect(described_class.decimal(1.25)).to eq("uno punto veinticinco")
    expect(described_class.decimal(0.05)).to eq("cero punto cero cinco")
  end
end
