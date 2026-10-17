# The pages each user opened (Presence: the recent pages the user with id 1
# sees on the card of who is connected). Session#visited! adds one per page
# and keeps the latest PageVisit::KEEP per user.
class CreatePageVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :page_visits do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :path, null: false
      t.string :title
      t.datetime :visited_at, null: false
    end
    add_index :page_visits, [ :user_id, :visited_at ]
  end
end
