require "rails_helper"

# Administrators may leave a shipment's local scale empty (Fernando,
# 2026-11-12): it takes no coffee out of the stock and has no difference
# between scales until someone completes it, even once sold.
RSpec.describe "Shipments without the local scale" do
  let(:admin) { create(:user, :admin) }
  let(:clerk) { create(:user).tap { create(:permission, user: it, module_key: "sales", can_read: true, can_create: true, can_update: true) } }
  let(:buyer) { create(:buyer) }

  def page = Nokogiri::HTML(response.body)

  def params(**extra)
    { shipment: { buyer_id: buyer.id, departed_at: Time.current.change(sec: 0), coffee_state: "wet_parchment", transport_mode: "driver",
                  driver_name: "Pedro Lara", origin_weight_mode: "single", **extra } }
  end

  before { create(:purchase, gross_weight: 2_000) }

  it "lets an administrator save it empty; it takes nothing from the stock until completed", :all_records do
    stock_before = CoffeeStock.new.rows.find { it.coffee_state == "wet_parchment" }.stock
    sign_in admin
    post sales_shipments_path, params: params(skip_origin: "1", origin_gross_weight: "900", origin_sacks: "5")
    shipment = Shipment.last
    expect(shipment).to be_origin_missing
    expect(shipment.origin_sacks).to be_nil
    expect(CoffeeStock.new.rows.find { it.coffee_state == "wet_parchment" }.stock).to eq(stock_before)
    expect(CoffeeLots.new.portions_for(shipment)).to be_empty
    expect(StockLedger.new(from: Time.zone.today - 1, to: Time.zone.today, coffee_state: "wet_parchment").entries.map(&:record)).not_to include(shipment)

    get sales_shipment_path(shipment)
    expect(page.at_css("[data-origin-missing]")).to be_present

    shipment.update!(received_on: Time.zone.today, destination_gross_weight: 900, destination_sacks: 5, destination_humidity_percent: 51,
                     destination_damage_percent: 0, receiving: true)
    expect(shipment.net_difference).to be_nil
    get sales_shipments_path
    expect(page.css("[data-no-origin]")).to be_present

    sign_in clerk
    patch sales_shipment_path(shipment), params: params(origin_gross_weight: "900", origin_sacks: "5", origin_humidity_percent: "51", origin_damage_percent: "0")
    shipment.reload
    expect(shipment).not_to be_origin_missing
    expect(shipment.net_difference).to be_present
    expect(CoffeeStock.new.rows.find { it.coffee_state == "wet_parchment" }.stock).to eq(stock_before - shipment.origin_net_weight)
  end

  it "is not for other users: they must weigh it" do
    sign_in clerk
    post sales_shipments_path, params: params(skip_origin: "1")
    expect(response).to have_http_status(:unprocessable_content)
    expect(Shipment.count).to eq(0)
  end

  it "sells without a difference and completes the local net of the sale afterwards" do
    shipment = Shipment.new(params[:shipment].merge(created_by: admin, skip_origin: "1", origin_skippable: true))
    shipment.save!
    shipment.update!(received_on: Time.zone.today, destination_gross_weight: 900, destination_sacks: 5, destination_humidity_percent: 51,
                     destination_damage_percent: 0, receiving: true)
    sale = SaleIssuer.new(buyer:, user: admin, shipment_ids: [ shipment.id ], sale: { price_unit: "pound", unit_price: "50", quintal_pounds: "120" }).call.sale
    expect(sale).to be_persisted
    expect(sale.origin_net_weight).to be_nil
    expect(sale.net_difference).to be_nil
    expect(SaleSummary.new(Sale.where(id: sale.id)).net_difference).to eq(0)

    sign_in admin
    get sales_sale_path(sale)
    expect(response).to have_http_status(:ok)
    get edit_sales_shipment_path(shipment)
    expect(response).to have_http_status(:ok)
    patch sales_shipment_path(shipment), params: params(skip_origin: "0", origin_gross_weight: "1000", origin_sacks: "5",
                                                        origin_humidity_percent: "51", origin_damage_percent: "0")
    expect(shipment.reload).not_to be_origin_missing
    expect(sale.reload.origin_net_weight).to eq(shipment.origin_net_weight)
    expect(sale.net_difference).to eq(sale.net_weight - shipment.origin_net_weight)
  end
end
