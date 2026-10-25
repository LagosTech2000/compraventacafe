# What kind of damage a parchment purchase had (Fernando, 2026-10-24):
# yellow, borer (broca), green, pulp, peeled; one or more when the damage
# is above 0.
class AddDamageTypesToPurchases < ActiveRecord::Migration[8.1]
  def change
    add_column :purchases, :damage_types, :string, array: true, default: [], null: false
  end
end
