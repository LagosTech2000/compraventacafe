# Who registers what the factories make (OwnedRecord, Fernando, 2026-11-13:
# whoever is not an administrator sees only what they registered): the
# user signed in last in the example, as when a person works signed in;
# before anyone signs in, a user of its own. A spec about someone else's
# records passes `created_by:`.
module SpecOwner
  mattr_accessor :user
end

RSpec.configure do |config|
  config.before { SpecOwner.user = nil }
end

# Specs about something else than own records, with several users or data
# made before anyone signs in: every user sees every record, as an
# administrator would. Own records are spec'd in spec/requests/own_records_spec.rb.
RSpec.configure do |config|
  config.before(:each, :all_records) { allow(OwnedRecord).to receive(:restricted?).and_return(false) }
end
