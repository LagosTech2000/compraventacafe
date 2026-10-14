class Session < ApplicationRecord
  # last_seen_at moves at most once per this long: a request does not write
  # on every page.
  SEEN_EVERY = 1.minute

  belongs_to :user

  # This session did something now (a page, a tab closing): Presence's
  # "recent activity". Skips callbacks and updated_at: it is not a change.
  def seen!(force: false)
    return unless force || last_seen_at.nil? || last_seen_at < SEEN_EVERY.ago

    update_column(:last_seen_at, Time.current)
  end
end
