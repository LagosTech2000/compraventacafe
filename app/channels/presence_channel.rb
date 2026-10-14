# Marks the connected user as online while subscribed (Presence). Sends
# nothing itself: the list travels by the Turbo stream "presence".
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    Presence.join(current_user)
  end

  def unsubscribed
    Presence.leave(current_user)
  end
end
