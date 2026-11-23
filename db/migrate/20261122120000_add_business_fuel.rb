# Fuel and oil of the business (Fernando, 2026-11-22: «gasolina de la
# empresa»): a supply marked as the business's own is not lent; each
# dispatch (a use by the business) goes to a vehicle and, optional, to the
# purchase that vehicle went for; a purchase says which vehicle went.
class AddBusinessFuel < ActiveRecord::Migration[8.1]
  def change
    add_column :supplies, :business_use, :boolean, default: false, null: false
    add_reference :supply_exits, :vehicle, foreign_key: true
    add_reference :supply_exits, :purchase, foreign_key: true
    add_reference :purchases, :vehicle, foreign_key: true
  end
end
