# The cash count leaves the account as it was counted (Fernando,
# 2026-11-20: «dejar cuadrada la caja desde hoy en adelante»): what it
# finds over or short enters the balance as its adjustment. The ones
# before keep 0: they only compared.
class AddAdjustmentToCashCounts < ActiveRecord::Migration[8.1]
  def change
    add_column :cash_counts, :adjustment, :decimal, precision: 14, scale: 2, null: false, default: 0
  end
end
