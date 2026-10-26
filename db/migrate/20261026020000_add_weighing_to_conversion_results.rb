# A conversion's result is weighed like a purchase or a shipment (Fernando,
# 2026-10-25): counted sacks, humidity and damage of the coffee that came
# out. Results registered before keep the stock proportion they used.
class AddWeighingToConversionResults < ActiveRecord::Migration[8.1]
  def change
    add_column :coffee_conversions, :output_sacks, :integer
    add_column :coffee_conversions, :output_tare, :decimal, precision: 12, scale: 2
    add_column :coffee_conversions, :output_humidity_percent, :decimal, precision: 5, scale: 2
    add_column :coffee_conversions, :output_damage_percent, :decimal, precision: 5, scale: 2
  end
end
