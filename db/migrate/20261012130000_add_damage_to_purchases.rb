# What damage takes off each parchment purchase, in pounds and lempiras,
# stored like the rest of the calculation so history does not change if the
# rule does. Existing purchases are filled from their stored inputs.
class AddDamageToPurchases < ActiveRecord::Migration[8.1]
  def up
    add_column :purchases, :damage_weight, :decimal, precision: 12, scale: 2
    add_column :purchases, :damage_amount, :decimal, precision: 14, scale: 2

    execute <<~SQL
      UPDATE purchases
      SET damage_weight = ROUND(GREATEST((gross_weight - tare) * (1 - humidity_percent / 100), 0) * damage_percent / 100, 2)
      WHERE coffee_state <> 'cherry' AND humidity_percent IS NOT NULL AND damage_percent IS NOT NULL
    SQL
    execute "UPDATE purchases SET damage_amount = ROUND(damage_weight * price_per_pound, 2) WHERE damage_weight IS NOT NULL"
  end

  def down
    remove_column :purchases, :damage_amount
    remove_column :purchases, :damage_weight
  end
end
