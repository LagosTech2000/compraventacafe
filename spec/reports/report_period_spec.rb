require "rails_helper"

RSpec.describe ReportPeriod do
  let(:today) { Date.new(2026, 10, 14) } # Wednesday

  def period(key, **options) = described_class.new(key, today:, **options)

  it "covers the listed periods up to today" do
    expect(period("today").range).to eq(today..today)
    expect(period("this_week").range).to eq(Date.new(2026, 10, 12)..today)
    expect(period("last_week").range).to eq(Date.new(2026, 10, 5)..Date.new(2026, 10, 11))
    expect(period("this_month").range).to eq(Date.new(2026, 10, 1)..today)
    expect(period("last_month").range).to eq(Date.new(2026, 9, 1)..Date.new(2026, 9, 30))
    expect(period("last_30_days").range).to eq(Date.new(2026, 9, 15)..today)
    expect(period("this_season").range).to eq(Date.new(2026, 9, 1)..today)
    expect(period("last_season").range).to eq(Date.new(2025, 9, 1)..Date.new(2026, 8, 31))
    expect(period("season_2024").range).to eq(Date.new(2024, 9, 1)..Date.new(2025, 8, 31))
    expect(period("all").range).to be_nil
  end

  it "compares with the same stretch one step back" do
    expect(period("this_month").previous.range).to eq(Date.new(2026, 9, 1)..Date.new(2026, 9, 14))
    expect(period("this_week").previous.range).to eq(Date.new(2026, 10, 5)..Date.new(2026, 10, 7))
    expect(period("last_month").previous.range).to eq(Date.new(2026, 8, 1)..Date.new(2026, 8, 31))
    expect(period("this_season").previous.range).to eq(Date.new(2025, 9, 1)..Date.new(2025, 10, 14))
    expect(period("season_2025").previous.range).to eq(Date.new(2024, 9, 1)..Date.new(2025, 8, 31))
    expect(period("custom", from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 10)).previous.range)
      .to eq(Date.new(2026, 9, 21)..Date.new(2026, 9, 30))
    expect(period("all").previous).to be_nil
    expect(period("custom", from: Date.new(2026, 10, 1)).previous).to be_nil
  end

  it "takes typed dates in either order and ignores unknown keys" do
    expect(period("custom", from: Date.new(2026, 10, 10), to: Date.new(2026, 10, 1)).range).to eq(Date.new(2026, 10, 1)..Date.new(2026, 10, 10))
    expect(period("custom").range).to be_nil
    expect(period("next_century").key).to eq("all")
  end
end
