# «Café corriente» (Fernando, 2026-11-12): a wet parchment purchase marked
# so does not count in the end-of-season retention (an open point: the rule
# waits for the retention to be built).
class AddCommonCoffeeToPurchases < ActiveRecord::Migration[8.1]
  def change
    add_column :purchases, :common_coffee, :boolean, default: false, null: false
  end
end
