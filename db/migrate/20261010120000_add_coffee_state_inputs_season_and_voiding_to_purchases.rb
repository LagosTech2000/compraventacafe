# Cherry is calculated with a yield instead of humidity, parchment also
# discounts damage, every purchase belongs to a season (September 1 to
# August 31), and a purchase can be voided instead of deleted.
class AddCoffeeStateInputsSeasonAndVoidingToPurchases < ActiveRecord::Migration[8.1]
  def up
    change_column_null :purchases, :humidity_percent, true
    add_column :purchases, :damage_percent, :decimal, precision: 5, scale: 2
    add_column :purchases, :yield_factor, :decimal, precision: 6, scale: 4
    add_column :purchases, :season_year, :integer
    add_column :purchases, :voided_at, :datetime
    add_reference :purchases, :voided_by, foreign_key: { to_table: :users }

    # Results already stored stay as they are; only the new inputs get filled.
    execute <<~SQL.squish
      UPDATE purchases SET damage_percent = 0 WHERE coffee_state <> 'cherry'
    SQL
    execute <<~SQL.squish
      UPDATE purchases
      SET season_year = CASE WHEN EXTRACT(MONTH FROM purchased_on) >= 9
                             THEN EXTRACT(YEAR FROM purchased_on)
                             ELSE EXTRACT(YEAR FROM purchased_on) - 1 END
    SQL

    change_column_null :purchases, :season_year, false
    add_index :purchases, :season_year
    add_index :purchases, :voided_at
  end

  def down
    remove_reference :purchases, :voided_by, foreign_key: { to_table: :users }
    remove_column :purchases, :voided_at
    remove_column :purchases, :season_year
    remove_column :purchases, :yield_factor
    remove_column :purchases, :damage_percent
    change_column_null :purchases, :humidity_percent, false, 0
  end
end
