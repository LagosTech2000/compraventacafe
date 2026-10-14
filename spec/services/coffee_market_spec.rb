require "rails_helper"

# The coffee exchange card (CoffeeMarket): reads Yahoo Finance's chart answer,
# keeps it in the cache and never breaks when the service fails.
RSpec.describe CoffeeMarket do
  include ActiveSupport::Testing::TimeHelpers

  it "reads the arabica quote, its last-session change and the closes of the month" do
    coffee_market_responds_with
    quote = described_class.quotes.sole

    expect(quote).to have_attributes(key: :arabica, symbol: "KC=F", exchange: "ICE Futures", currency: "USX",
                                     contract: "Coffee Dec 26", price: BigDecimal("293.2"),
                                     day_low: BigDecimal("290.3"), year_high: BigDecimal("437.95"))
    # Days without a close are skipped; the previous session is the one before the last.
    expect(quote.history.map(&:last)).to eq([ 289.05, 286.95, 290.6 ].map { BigDecimal(it.to_s) })
    expect(quote.previous_close).to eq(BigDecimal("286.95"))
    expect(quote.change).to eq(BigDecimal("6.25"))
    expect(quote.change_percent.round(2)).to eq(BigDecimal("2.18"))
    expect(quote.dollars_per_pound).to eq(BigDecimal("2.932"))
    expect(quote.at).to eq(Time.zone.at(1791912596))
  end

  it "keeps the quote in the cache for every page view" do
    coffee_market_responds_with
    2.times { described_class.quotes }

    expect(described_class).to have_received(:request).once
  end

  it "answers nothing when the service fails, and waits before asking again" do
    expect(described_class.quotes).to eq([])
    expect(described_class.quotes).to eq([])
    expect(described_class).to have_received(:request).once

    travel CoffeeMarket::RETRY_AFTER + 1.second do
      coffee_market_responds_with
      expect(described_class.quotes.size).to eq(1)
    end
  end

  it "answers nothing for an answer without a price" do
    allow(described_class).to receive(:request).and_return({ chart: { result: nil } }.to_json)

    expect(described_class.quotes).to eq([])
  end
end
