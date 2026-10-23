# A mark that changes with every change of the business's data: each
# Auditable record bumps it when its transaction commits. What is cached
# from that data (the reports' figures and charts, Report#cached) keeps it in
# its key, so a change is never hidden behind an old copy. Lives in the
# cache, like what it guards: if the cache forgets it, a new mark starts
# and the old copies are no longer found.
module DataVersion
  KEY = "data_version".freeze

  def self.current = Rails.cache.fetch(KEY) { SecureRandom.hex(8) }
  def self.bump! = Rails.cache.write(KEY, SecureRandom.hex(8))
end
