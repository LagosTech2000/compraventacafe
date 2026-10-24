require "rails_helper"

# Comercialización (Fernando, 2026-10-23): a truck leaves, is weighed at the
# buyer's, is sold on the buyer's net and collected; the stock follows.
RSpec.describe "Sales flow" do
  let(:user) do
    create(:user).tap do |u|
      create(:permission, user: u, module_key: "sales", can_read: true, can_create: true, can_update: true, can_destroy: true)
    end
  end
  let(:buyer) { create(:buyer, name: "Beneficio Henola") }

  before { sign_in user }

  it "ships, weighs at destination, sells by the quintal of 100 lb, collects and prints" do
    create(:purchase, gross_weight: 2_000, humidity_percent: 51) # in stock: (2,000 − 13) × 0.49 = 973.63 lb

    post sales_shipments_path, params: { shipment: {
      buyer_id: buyer.id, departed_at: Time.current, coffee_state: "wet_parchment", remission_number: "329",
      origin_gross_weight: "1000", origin_sacks: "6", origin_humidity_percent: "51", origin_damage_percent: ""
    } }
    shipment = Shipment.last
    expect(response).to redirect_to(sales_shipment_path(shipment))
    expect(shipment).to have_attributes(number: 1, origin_tare: 6, origin_net_weight: BigDecimal("487.06"), status: "in_transit")
    expect(CoffeeStock.new.row("wet_parchment").stock).to eq(BigDecimal("973.63") - BigDecimal("487.06"))

    get sales_shipment_path(shipment)
    expect(response.body).to include("Salida 0001", "Registrar peso en destino")

    get edit_sales_shipment_arrival_path(shipment)
    expect(response).to have_http_status(:ok)
    patch sales_shipment_arrival_path(shipment), params: { shipment: {
      received_on: Time.zone.today, weight_note_number: "EPNP43275", destination_gross_weight: "980", destination_sacks: "6",
      destination_humidity_percent: "51", destination_damage_percent: "1"
    } }
    shipment.reload
    # (980 − 6) × 0.49 × 0.99 = 472.49
    expect(shipment.destination_net_weight).to eq(BigDecimal("472.49"))
    expect(shipment.net_difference).to eq(BigDecimal("-14.57"))
    expect(shipment.status).to eq("received")

    get new_sales_sale_path
    expect(response.body).to include("Beneficio Henola")
    get new_sales_sale_path(buyer_id: buyer.id)
    expect(response.body).to include("Salida 0001")

    post sales_sales_path, params: { buyer_id: buyer.id, sale: {
      shipment_ids: [ shipment.id ], sold_on: Time.zone.today, price_unit: "quintal", unit_price: "6000",
      buyer_document_number: "Comprobante 57", payment_status: "partial", amount: "10000", payment_method: "transfer"
    } }
    sale = Sale.last
    expect(response).to redirect_to(sales_sale_path(sale))
    # 472.49 lb ÷ 100 × L 6,000
    expect(sale).to have_attributes(total: BigDecimal("28349.40"), payment_status: "partial", coffee_state: "wet_parchment")
    expect(shipment.reload.status).to eq("sold")

    get sales_sale_path(sale)
    expect(response.body).to include("Nota de venta", "Comprobante 57", "ORIGINAL", "COPIA")

    post sales_sale_payments_path(sale), params: { sale_payment: { amount: sale.balance_due, paid_on: Time.zone.today, payment_method: "cash" } }
    payment = SalePayment.last
    expect(response).to redirect_to(sales_sale_path(sale, receipt: payment.id))
    expect(sale.reload).to be_paid
    get sales_sale_payment_path(sale, payment)
    expect(response.body).to include("Recibo de cobro")

    [ sales_root_path, sales_shipments_path, sales_sales_path, sales_stock_path, sales_daily_close_path,
      sales_buyers_path, sales_buyer_path(buyer), sales_buyer_path(buyer, tab: "shipments"), sales_buyer_path(buyer, tab: "payments") ].each do |path|
      get path
      expect(response).to have_http_status(:ok), path
    end
  end

  it "marks the shipments over the site's tolerance and filters them" do
    SiteSetting.instance.update!(weight_tolerance_percent: 1)
    over = create(:shipment, :received, buyer:, destination_gross_weight: 900)   # about −9 %
    create(:shipment, :received, buyer:, destination_gross_weight: 998)          # under 1 %

    get sales_root_path
    expect(response.body).to include("1 salida de esta temporada tiene una diferencia de peso mayor al 1 %")
    get sales_shipments_path(over_tolerance: 1)
    expect(response.body).to include("Solo con diferencia mayor al 1 %")
    rows = Nokogiri::HTML(response.body).css("tbody tr")
    expect(rows.map { it["id"] }).to eq([ "shipment_#{over.id}" ])
    expect(rows.first.at_css("[data-over-tolerance='true']")).to be_present
    create(:permission, user:, module_key: "reports", can_read: true)
    get reports_report_path("shipments", period: "all", over_tolerance: 1)
    expect(response).to have_http_status(:ok)
  end

  it "voids a sale without payments and frees its shipments for another sale" do
    sale = create(:sale, buyer:)
    shipment = sale.shipments.first
    patch void_sales_sale_path(sale), params: { sale: { void_reason: "Diferencia de peso" } }
    expect(sale.reload).to be_voided
    expect(sale.void_reason).to eq("Diferencia de peso")
    expect(shipment.reload.status).to eq("received")
    expect(create(:sale, buyer:, shipments: [ shipment ])).to be_persisted
  end

  it "does not sell the same shipment twice nor mix coffee states" do
    sale = create(:sale, buyer:)
    result = SaleIssuer.new(buyer:, user:, shipment_ids: sale.shipments.ids, sale: { price_unit: "pound", unit_price: 60 }).call
    expect(result).not_to be_success

    wet = create(:shipment, :received, buyer:)
    dry = create(:shipment, :received, buyer:, coffee_state: "dry_parchment", origin_humidity_percent: 12, destination_humidity_percent: 12)
    result = SaleIssuer.new(buyer:, user:, shipment_ids: [ wet.id, dry.id ], sale: { price_unit: "pound", unit_price: 60 }).call
    expect(result.sale.errors[:lines]).to be_present
  end

  it "voids a shipment back to stock, but not one in a sale" do
    shipment = create(:shipment, buyer:)
    patch void_sales_shipment_path(shipment)
    expect(shipment.reload).to be_voided
    expect(CoffeeStock.new.row("wet_parchment").shipped).to eq(0)

    sale = create(:sale, buyer:)
    patch void_sales_shipment_path(sale.shipments.first)
    expect(sale.shipments.first.reload).not_to be_voided
  end
end
