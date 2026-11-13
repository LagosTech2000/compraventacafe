class Current < ActiveSupport::CurrentAttributes
  attribute :session, :ip_address, :request_id
  # The weight tolerance of the site settings, read once per request (WeightTolerance).
  attribute :weight_tolerance
  delegate :user, to: :session, allow_nil: true

  # Who sees only what they registered (OwnedRecord): the user of the
  # request unless an administrator; nobody outside a request.
  def owner = (signed_in = user) && !signed_in.admin? ? signed_in : nil
end
