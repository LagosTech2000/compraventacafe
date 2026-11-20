# A reason when a difference passes its tolerance (Fernando, 2026-11-18):
# purchases ↔ local scale (shrink) and local scale ↔ buyer. Asked, never
# blocking.
class AddToleranceReasons < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :shrink_tolerance_percent, :decimal, precision: 5, scale: 2
    add_column :shipments, :shrink_reason, :string, limit: 500
    add_column :shipments, :difference_reason, :string, limit: 500
  end
end
