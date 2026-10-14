# When each session last did something (Presence: "recent activity" on the
# home page, Fernando 2026-10-14). Old sessions stay empty: not recent.
class AddLastSeenAtToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :last_seen_at, :datetime
    add_index :sessions, :last_seen_at
  end
end
