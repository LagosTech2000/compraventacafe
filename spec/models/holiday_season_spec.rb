require "rails_helper"

# The Christmas season (Fernando, 2026-11-15): from November 15, all of
# December and the first week of January.
RSpec.describe HolidaySeason do
  it "lasts from November 15 to January 7" do
    expect(described_class.christmas?(Date.new(2026, 11, 14))).to be(false)
    expect(described_class.christmas?(Date.new(2026, 11, 15))).to be(true)
    expect(described_class.christmas?(Date.new(2026, 12, 31))).to be(true)
    expect(described_class.christmas?(Date.new(2027, 1, 7))).to be(true)
    expect(described_class.christmas?(Date.new(2027, 1, 8))).to be(false)
    expect(described_class.christmas?(Date.new(2027, 6, 1))).to be(false)
  end
end
