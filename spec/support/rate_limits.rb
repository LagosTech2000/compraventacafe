# The rate limits count in memory (Rails.cache, Rack::Attack's own store):
# each example starts from zero. Rack::Attack is off in tests; with_rack_attack
# turns it on for the specs that check it.
module RateLimitHelpers
  def with_rack_attack
    Rack::Attack.enabled = true
    yield
  ensure
    Rack::Attack.enabled = false
  end
end

RSpec.configure do |config|
  config.include RateLimitHelpers
  config.before do
    Rails.cache.clear
    Rack::Attack.cache.store.clear
  end
end
