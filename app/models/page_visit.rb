# A page a user opened (presence.js → Session#visited!), for the card of who
# is connected that only the user with id 1 sees (Presence::WATCHER_IDS).
# Not business data: not audited, left out of the backup like the sessions,
# and only the latest KEEP per user stay.
class PageVisit < ApplicationRecord
  KEEP = 50

  belongs_to :user

  scope :latest, -> { order(visited_at: :desc, id: :desc) }

  # Records the page and drops the user's oldest beyond KEEP.
  def self.record!(user:, path:, title:, at: Time.current)
    create!(user:, path:, title:, visited_at: at)
    where(user:).where.not(id: where(user:).latest.limit(KEEP).select(:id)).delete_all
  end
end
