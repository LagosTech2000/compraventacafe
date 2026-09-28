# Reference data is loaded by a migration, which schema:load skips.
RSpec.configure do |config|
  config.before(:suite) { HondurasDivisions.load! }
end
