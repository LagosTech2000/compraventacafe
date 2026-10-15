# The page each session is on (Presence: what the user with id 1 sees when
# hovering over who is connected).
class AddLastPageToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :last_path, :string
    add_column :sessions, :last_page_title, :string
  end
end
