# What the carrier is paid for that trip (client, 2026-10-30: «precio de
# viaje, lo que se le paga al transportista por ese viaje»). Optional, only
# with a carrier.
class AddTripPriceToShipments < ActiveRecord::Migration[8.1]
  def change
    add_column :shipments, :trip_price, :decimal, precision: 12, scale: 2
  end
end
