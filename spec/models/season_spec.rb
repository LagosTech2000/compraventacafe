require "rails_helper"

RSpec.describe Season do
  include ActiveSupport::Testing::TimeHelpers

  it "starts on September 1 and is named after the year it starts in" do
    expect(described_class.for(Date.new(2026, 9, 1)).year).to eq(2026)
    expect(described_class.for(Date.new(2027, 8, 31)).year).to eq(2026)
    expect(described_class.for(Date.new(2027, 9, 1)).year).to eq(2027)
    expect(described_class.for(Date.new(2026, 1, 15)).year).to eq(2025)
  end

  it "runs to August 31 of the next year" do
    season = described_class.new(2026)
    expect(season.dates).to eq(Date.new(2026, 9, 1)..Date.new(2027, 8, 31))
    expect(season).to include(Date.new(2027, 2, 28))
    expect(season).not_to include(Date.new(2027, 9, 1))
  end

  it "knows the current one" do
    travel_to Date.new(2026, 10, 10) do
      expect(described_class.current).to eq(described_class.new(2026))
    end
  end
end
