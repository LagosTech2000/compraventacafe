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
  # Who sees, on hover, each user's last activity and the page they are on
  # (Fernando, 2026-10-15). Only they get those details: their home page
  # listens to WATCH_STREAM instead of STREAM, and only theirs renders it.
  WATCHER_IDS = [ 1 ].freeze
  STREAM = :presence
  WATCH_STREAM = [ :presence, :watch ].freeze
  TARGET = "active-users"
  # The panel is morphed, not swapped: a card open under the pointer stays
  # open, with its scroll and focus.
  MORPH = { method: :morph }.freeze
  # Avatars shown; the rest go in a "+N" with their names.
  AVATARS = 6
  RECENT_WINDOW = 60.minutes
  # Recent pages and changes on each user's card, for the watchers.
  CARD_ITEMS = 20

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

    # Someone opened a page: only the watchers' panel says which.
    def page_changed(user)
      broadcast_to_watchers unless HIDDEN_USER_IDS.include?(user.id)
    end

    def watcher?(user) = user&.active? && WATCHER_IDS.include?(user.id)

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

    # What dashboard/_active_users renders. With pages: true (watchers
    # only), for each user too: their latest session (last activity and its
    # page), the pages they opened (PageVisit) and what they did (their
    # audit events), the latest CARD_ITEMS of each, by user id.
    def panel_locals(pages: false)
      users = visible_users.to_a
      recent = recent_users.to_a
      locals = { users:, recent:, pages: nil, visits: {}, changes: {} }
      return locals unless pages

      ids = (users + recent).map(&:id)
      locals.merge(pages: latest_sessions(users + recent),
                   visits: latest_per_user(PageVisit.where(user_id: ids), "visited_at DESC, id DESC"),
                   changes: latest_per_user(AuditEvent.where(user_id: ids), "created_at DESC, id DESC"))
    end

    # The most recently active session of each user, by user id.
    def latest_sessions(users)
      Session.where(user_id: users.map(&:id)).where.not(last_seen_at: nil)
             .order(:user_id, last_seen_at: :desc).to_a.uniq(&:user_id).index_by(&:user_id)
    end

    # The latest CARD_ITEMS rows of each user in one query.
    def latest_per_user(scope, order)
      table = scope.table_name
      ranked = scope.select("#{table}.*, ROW_NUMBER() OVER (PARTITION BY #{table}.user_id ORDER BY #{order}) AS position")
      scope.klass.from(ranked, table).where("position <= ?", CARD_ITEMS).order(Arel.sql(order)).group_by(&:user_id)
    end

    def reset! = @lock.synchronize { @connections.clear }

    private
      def broadcast
        Turbo::StreamsChannel.broadcast_replace_to(STREAM, target: TARGET, partial: "dashboard/active_users",
                                                           locals: panel_locals, attributes: MORPH)
        broadcast_to_watchers
      end

      def broadcast_to_watchers
        Turbo::StreamsChannel.broadcast_replace_to(WATCH_STREAM, target: TARGET, partial: "dashboard/active_users",
                                                                 locals: panel_locals(pages: true), attributes: MORPH)
      end
  end
end
