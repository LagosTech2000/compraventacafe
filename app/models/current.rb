class Current < ActiveSupport::CurrentAttributes
  attribute :session, :ip_address, :request_id
  # The weight tolerance of the site settings, read once per request (WeightTolerance).
  attribute :weight_tolerance
  delegate :user, to: :session, allow_nil: true
end
