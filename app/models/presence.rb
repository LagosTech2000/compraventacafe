# Who is using the system right now (Fernando, 2026-10-13), for the
# "Usuarios conectados" panel of the home page. Every signed-in page keeps one
# PresenceChannel subscription (presence.js); a user is online while any of
# their tabs is connected. When someone comes or goes, the panel of every open
# home page is replaced (Turbo stream "presence"): only names, no business data.
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

    def reset! = @lock.synchronize { @connections.clear }

    private
      def broadcast
        Turbo::StreamsChannel.broadcast_replace_to(STREAM, target: TARGET, partial: "dashboard/active_users",
                                                           locals: { users: visible_users.to_a })
      end
  end
end
