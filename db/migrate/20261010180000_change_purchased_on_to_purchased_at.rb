# A purchase records the moment it was weighed, not only the day. Existing
# purchases take the time they were registered when it was the same day,
# otherwise the start of their day (Tegucigalpa time).
class ChangePurchasedOnToPurchasedAt < ActiveRecord::Migration[8.1]
  ZONE = "America/Tegucigalpa".freeze

  def up
    add_column :purchases, :purchased_at, :datetime
    execute <<~SQL.squish
      UPDATE purchases
      SET purchased_at = CASE
        WHEN (created_at AT TIME ZONE 'UTC' AT TIME ZONE '#{ZONE}')::date = purchased_on THEN created_at
        ELSE (purchased_on::timestamp AT TIME ZONE '#{ZONE}') AT TIME ZONE 'UTC'
      END
    SQL
    change_column_null :purchases, :purchased_at, false
    add_index :purchases, :purchased_at
    remove_column :purchases, :purchased_on
  end

  def down
    add_column :purchases, :purchased_on, :date
    execute <<~SQL.squish
      UPDATE purchases SET purchased_on = (purchased_at AT TIME ZONE 'UTC' AT TIME ZONE '#{ZONE}')::date
    SQL
    change_column_null :purchases, :purchased_on, false
    add_index :purchases, :purchased_on
    remove_column :purchases, :purchased_at
  end
end
