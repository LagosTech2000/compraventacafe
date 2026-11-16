require "rails_helper"

# Editing and removing a shipment's scales (Fernando, 2026-11-15: «para
# tener todo cuadrado en las ventas»): unsold, whoever edits Salidas; sold,
# only an administrator, and the sale works itself out again.
RSpec.describe "Shipment scales" do
  let(:admin) { create(:user, :admin) }
  let(:clerk) { create(:user).tap { create(:permission, user: it, module_key: "sales", can_read: true, can_create: true, can_update: true, can_destroy: true) } }
  let(:buyer) { create(:buyer) }

  it "removes the buyer's scale of an unsold shipment, back to in transit" do
    shipment = create(:shipment, :received, buyer:, created_by: clerk)
    sign_in clerk
    delete sales_shipment_scale_path(shipment, side: "destination")
    expect(flash[:notice]).to eq("Se quitó la báscula del comprador: la salida vuelve a «En camino».")
    expect(shipment.reload).to have_attributes(received_on: nil, destination_net_weight: nil, status: "in_transit")
  end

  it "lets only an administrator change a sold shipment's scales, and its sale follows" do
    sale = create(:sale, buyer:, user: admin, shipments: [ create(:shipment, :received, buyer:) ])
    shipment = sale.shipments.sole
    total = sale.total

    sign_in clerk
    patch sales_shipment_arrival_path(shipment), params: { shipment: { destination_gross_weight: "1100", received_on: shipment.received_on } }
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")

    sign_in admin
    patch sales_shipment_arrival_path(shipment), params: { shipment: { destination_gross_weight: "1100", destination_sacks: shipment.destination_sacks,
                                                                       destination_humidity_percent: "51", destination_damage_percent: "0",
                                                                       received_on: shipment.received_on, lock_version: shipment.lock_version } }
    shipment.reload
    sale.reload
    expect(shipment.destination_gross_weight).to eq(1_100)
    expect(sale.net_weight).to eq(shipment.destination_net_weight)
    expect(sale.lines.sole.net_weight).to eq(shipment.destination_net_weight)
    expect(sale.total).to be > total

    # The sale charges the buyer's scale: it is not removed while sold.
    delete sales_shipment_scale_path(shipment, side: "destination")
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")
    expect(shipment.reload.destination_net_weight).to be_present
    expect { shipment.remove_destination! }.to raise_error(ActiveRecord::RecordInvalid, /quítala de la venta o anula la venta/)

    delete sales_shipment_scale_path(shipment, side: "origin")
    expect(shipment.reload.origin_net_weight).to be_nil
    expect(sale.reload.origin_net_weight).to be_nil
    expect(sale.lines.sole.origin_net_weight).to be_nil
  end
end
