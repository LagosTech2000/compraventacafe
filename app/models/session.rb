class Session < ApplicationRecord
  # last_seen_at moves at most once per this long: a request does not write
  # on every page.
  SEEN_EVERY = 1.minute
  PATH_LENGTH = 300
  TITLE_LENGTH = 150

  belongs_to :user

  # This session did something now (a page, a tab closing): Presence's
  # "recent activity". Skips callbacks and updated_at: it is not a change.
  def seen!(force: false)
    return unless force || last_seen_at.nil? || last_seen_at < SEEN_EVERY.ago

    update_column(:last_seen_at, Time.current)
  end

  # The page this session just opened (presence.js): its path and title, for
  # the user with id 1 (Presence::WATCHER_IDS), who also sees the user's
  # recent pages (PageVisit). Also counts as activity.
  def visited!(path:, title:)
    path = path.to_s.first(PATH_LENGTH)
    # Only this app's own paths: never "//host" or "/\host", which a
    # browser opens as another site (the watcher's card links to it).
    path = nil unless path.match?(%r{\A/(?![/\\])})
    title = title.to_s.squish.first(TITLE_LENGTH).presence
    now = Time.current
    transaction do
      update_columns(last_path: path, last_page_title: title, last_seen_at: now)
      PageVisit.record!(user:, path:, title:, at: now) if path
    end
  end
end
