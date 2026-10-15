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
  # the user with id 1 (Presence::WATCHER_IDS). Also counts as activity.
  def visited!(path:, title:)
    path = path.to_s.first(PATH_LENGTH)
    path = nil unless path.start_with?("/")
    update_columns(last_path: path, last_page_title: title.to_s.squish.first(TITLE_LENGTH).presence,
                   last_seen_at: Time.current)
  end
end
