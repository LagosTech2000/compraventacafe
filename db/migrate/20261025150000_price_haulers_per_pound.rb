# A carrero earns net pounds × their price per pound, nothing else
# (Fernando, 2026-10-24: «quitar comisión de los carreros y poner precio por
# libra neta nada más»). Each one starts with the price equal to their old
# terms (can price × percent ÷ 16.5 lb), editable. Purchases already made
# keep their commission and the terms they were calculated with; new ones
# keep the price per pound of their day.
class PriceHaulersPerPound < ActiveRecord::Migration[8.1]
  def up
    add_column :haulers, :price_per_pound, :decimal, precision: 12, scale: 4
    execute "UPDATE haulers SET price_per_pound = GREATEST(ROUND(can_price * commission_percent / 100 / 16.5, 4), 0.0001)"
    change_column_null :haulers, :price_per_pound, false
    remove_column :haulers, :commission_percent
    remove_column :haulers, :can_price
    add_column :purchases, :hauler_price_per_pound, :decimal, precision: 12, scale: 4
  end

  def down
    remove_column :purchases, :hauler_price_per_pound
    add_column :haulers, :commission_percent, :decimal, precision: 5, scale: 2
    add_column :haulers, :can_price, :decimal, precision: 12, scale: 2
    execute "UPDATE haulers SET commission_percent = 100, can_price = ROUND(price_per_pound * 16.5, 2)"
    change_column_null :haulers, :commission_percent, false
    change_column_null :haulers, :can_price, false
    remove_column :haulers, :price_per_pound
  end
end
