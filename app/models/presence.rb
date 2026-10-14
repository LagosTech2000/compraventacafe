# Who is using the system right now (Fernando, 2026-10-13), for the
# "Usuarios conectados" panel of the home page. Every signed-in page keeps one
# PresenceChannel subscription (presence.js); a user is online while any of
# their tabs is connected. When someone comes or goes, the panel of every open
# home page is replaced (Turbo stream "presence"): only names, no business data.
#
# Next to them, with a grey ring instead of the green dot, the users not
# connected now whose session did something in the last RECENT_WINDOW
# (Session#last_seen_at; Fernando, 2026-10-14): a phone locks or a tab
# sleeps and the connection drops, but the session is still in use. Signing
# out destroys the session, so it leaves the list.
#
# Kept in this process's memory, like the Action Cable "async" adapter: one
# instance and one Puma process. After a restart the browsers reconnect and
# subscribe again, so the list fills back by itself.
module Presence
  # The user with id 1 never shows as online (Fernando, 2026-10-13); they
  # still see who else is.
  HIDDEN_USER_IDS = [ 1 ].freeze
  STREAM = :presence
  TARGET = "active-users"
  # Avatars shown; the rest go in a "+N" with their names.
  AVATARS = 6
  RECENT_WINDOW = 60.minutes

  @connections = Hash.new(0)
  @lock = Mutex.new

  class << self
    def join(user)
      broadcast if @lock.synchronize { (@connections[user.id] += 1) == 1 }
    end

    def leave(user)
      gone = @lock.synchronize do
        @connections[user.id] -= 1
        @connections.delete(user.id) if @connections[user.id] <= 0
        !@connections.key?(user.id)
      end
      broadcast if gone
    end

    def online_user_ids = @lock.synchronize { @connections.keys }

    # The users to show: online, active and not hidden, by name.
    def visible_users
      ids = online_user_ids - HIDDEN_USER_IDS
      ids.empty? ? User.none : User.active.where(id: ids).includes(:photo_info).order(:name)
    end

    # Not connected now, with recent activity: most recent first, each with
    # its last_seen_at (the latest of their sessions).
    def recent_users
      User.active.joins(:sessions).where(sessions: { last_seen_at: RECENT_WINDOW.ago.. })
          .where.not(id: online_user_ids + HIDDEN_USER_IDS).group("users.id")
          .select("users.*, MAX(sessions.last_seen_at) AS last_seen_at")
          .includes(:photo_info).order("last_seen_at DESC")
    end

    # What dashboard/_active_users renders.
    def panel_locals = { users: visible_users.to_a, recent: recent_users.to_a }

    def reset! = @lock.synchronize { @connections.clear }

    private
      def broadcast
        Turbo::StreamsChannel.broadcast_replace_to(STREAM, target: TARGET, partial: "dashboard/active_users",
                                                           locals: panel_locals)
      end
  end
end
