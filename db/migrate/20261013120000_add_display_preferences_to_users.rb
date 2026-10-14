# Each user's own display settings (Fernando, 2026-10-13): pages that open
# over the current one show in a centered modal or in a drawer from the
# right, and the main navigation sits at the top or on the left.
class AddDisplayPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :window_style, :string, null: false, default: "modal"
    add_column :users, :nav_position, :string, null: false, default: "top"
  end
end
