# Specs never call outside services: the coffee exchange (CoffeeMarket)
# answers "unavailable" unless a spec gives it a response. Who is online
# (Presence) lives in memory: each example starts with nobody.
module OutsideServiceHelpers
  def coffee_market_responds_with(fixture = "coffee_market_kc.json")
    allow(CoffeeMarket).to receive(:request).and_return(file_fixture(fixture).read)
  end
end

RSpec.configure do |config|
  config.include OutsideServiceHelpers
  config.before do
    allow(CoffeeMarket).to receive(:request).and_raise(SocketError, "no outside services in tests")
    Presence.reset!
  end
end
