class Current < ActiveSupport::CurrentAttributes
  attribute :session, :ip_address, :request_id
  # The weight tolerance of the site settings, read once per request (WeightTolerance).
  attribute :weight_tolerance
  # The shrink tolerance (purchases ↔ local scale), once per request.
  attribute :shrink_tolerance
  # The submodules of the developments quoted apart that are off, read once (PaidFeature).
  attribute :locked_submodules
  # Set while a data-maintenance task applies or reverts (Maintenance::Runner):
  # it may fill what is closed to the users (lots of sold shipments).
  attribute :maintenance
  delegate :user, to: :session, allow_nil: true

  # Who sees only what they registered (OwnedRecord): the user of the
  # request unless an administrator; nobody outside a request.
  def owner = (signed_in = user) && !signed_in.admin? ? signed_in : nil
end
