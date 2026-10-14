# Marks the connected user as online while subscribed (Presence). Sends
# nothing itself: the list travels by the Turbo stream "presence". Closing
# the tab counts as the session's last activity (recent activity).
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    Presence.join(current_user)
  end

  def unsubscribed
    current_session&.seen!(force: true)
    Presence.leave(current_user)
  end
end
