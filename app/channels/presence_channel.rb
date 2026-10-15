# Marks the connected user as online while subscribed (Presence). Sends
# nothing itself: the list travels by the Turbo stream "presence". Closing
# the tab counts as the session's last activity (recent activity). Each page
# it opens is noted on the session, for the user with id 1 (Presence::WATCHER_IDS).
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    Presence.join(current_user)
  end

  # A page opened in any tab (presence.js): { "path", "title" }.
  def visit(data)
    return unless current_session

    current_session.visited!(path: data["path"], title: data["title"])
    Presence.page_changed(current_user)
  end

  def unsubscribed
    current_session&.seen!(force: true)
    Presence.leave(current_user)
  end
end
