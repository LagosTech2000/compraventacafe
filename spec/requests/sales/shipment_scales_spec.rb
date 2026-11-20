require "rails_helper"

# A shipment's scales (Fernando, 2026-11-15) while it is on its way; weighed
# at destination or sold, it is closed for everyone, administrators too
# (Fernando, 2026-11-18): weighed and not sold, its buyer's scale is removed
# to correct it; sold, the sale is voided first.
RSpec.describe "Shipment scales" do
  let(:admin) { create(:user, :admin) }
  let(:clerk) { create(:user).tap { create(:permission, user: it, module_key: "sales", can_read: true, can_create: true, can_update: true, can_destroy: true) } }
  let(:buyer) { create(:buyer) }

  def page = Nokogiri::HTML(response.body)

  it "removes the buyer's scale of an unsold shipment, back to in transit, and then it is edited again" do
    shipment = create(:shipment, :received, buyer:, created_by: clerk)
    sign_in clerk
    get sales_shipment_path(shipment)
    expect(page.at_css("[data-closed-scales]").text).to include("quita la báscula del comprador")
    expect(page.css("a").map(&:text)).not_to include("Editar")

    patch sales_shipment_path(shipment), params: { shipment: { observations: "Revisada", origin_gross_weight: "900" } }
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")

    delete sales_shipment_scale_path(shipment, side: "destination")
    expect(flash[:notice]).to eq("Se quitó la báscula del comprador: la salida vuelve a «En camino».")
    expect(shipment.reload).to have_attributes(received_on: nil, destination_net_weight: nil, status: "in_transit")
    get sales_shipment_path(shipment)
    expect(page.css("a").map(&:text)).to include("Editar")
  end

  it "keeps a weighed shipment's weights and dates in the model, for everyone" do
    shipment = create(:shipment, :received, buyer:)
    Current.session = admin.sessions.create!
    expect(shipment.update(origin_gross_weight: 900)).to be(false)
    expect(shipment.errors.full_messages.join).to include("ya se pesó en destino")
    expect(shipment.reload.update(observations: "Revisada", trip_price: nil)).to be(true)
  ensure
    Current.reset
  end

  it "closes a sold shipment's scales and dates to an administrator too" do
    sale = create(:sale, buyer:, user: admin, shipments: [ create(:shipment, :received, buyer:, departed_at: 3.days.ago) ])
    shipment = sale.shipments.sole
    sign_in admin

    get sales_shipment_path(shipment)
    expect(page.at_css("[data-closed-scales]").text).to include("primero anula la venta")
    patch sales_shipment_arrival_path(shipment), params: { shipment: { destination_gross_weight: "1100", received_on: shipment.received_on } }
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")
    patch sales_shipment_path(shipment), params: { shipment: { departed_at: 5.days.ago.change(hour: 12) } }
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")
    delete sales_shipment_scale_path(shipment, side: "origin")
    expect(shipment.reload.origin_net_weight).to be_present

    # The sale charges the buyer's scale: it is not removed while sold.
    delete sales_shipment_scale_path(shipment, side: "destination")
    expect(shipment.reload.destination_net_weight).to be_present
    expect { shipment.remove_destination! }.to raise_error(ActiveRecord::RecordInvalid, /quítala de la venta o anula la venta/)
    expect(shipment.update(departed_at: 5.days.ago)).to be(false)
    expect(shipment.errors.full_messages.join).to include("está en la venta #{sale.display_number}")
  end

  it "still completes a local scale left empty after the sale, and the sale follows" do
    shipment = create(:shipment, :received, buyer:, created_by: clerk, skip_origin: "1", origin_skippable: true)
    sale = create(:sale, buyer:, user: admin, shipments: [ shipment ])
    expect(sale.origin_net_weight).to be_nil

    sign_in clerk
    patch sales_shipment_path(shipment), params: { shipment: { origin_gross_weight: "1000", origin_sacks: "6", origin_humidity_percent: "51",
                                                               origin_damage_percent: "0", lock_version: shipment.reload.lock_version } }
    expect(shipment.reload.origin_net_weight).to be_present
    expect(sale.reload.origin_net_weight).to eq(shipment.origin_net_weight)
  end
end
