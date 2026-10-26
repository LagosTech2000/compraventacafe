# Cherry spoils if it waits (client, 2026-10-26): a warning after 12 hours
# without processing and a critical alert after 24, both configurable.
class AddCherryAlertHoursToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :cherry_warning_hours, :integer, null: false, default: 12
    add_column :site_settings, :cherry_critical_hours, :integer, null: false, default: 24
  end
end
