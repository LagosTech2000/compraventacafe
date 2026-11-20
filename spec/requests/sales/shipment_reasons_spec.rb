require "rails_helper"

# A reason when a difference passes its tolerance (Fernando, 2026-11-18):
# the shrink (purchases of its lots ↔ local scale) and the buyer's scale ↔
# local, each with its tolerance in Configuración del sitio. Asked by the
# forms that enter them, never blocking otherwise.
RSpec.describe "Reasons for the differences over the tolerance" do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer) }
  let(:buyer) { create(:buyer) }
  # (1,000 − 7) × 0.49 = 486.57 net
  let(:purchase) { create(:purchase, producer:, gross_weight: 1_000, humidity_percent: 51, purchased_at: 1.hour.ago) }
  let(:batch) do
    invoice = InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
    create(:coffee_batch, gross_limit: 1_000).tap { it.batch_invoices.create!(invoice:, percent: 100, created_by: admin) }
  end

  def page = Nokogiri::HTML(response.body)

  def ship(gross, **extra)
    post sales_shipments_path, params: { shipment: {
      buyer_id: buyer.id, departed_at: Time.current, coffee_state: "wet_parchment", warehouse_id: Warehouse.main!.id,
      origin_gross_weight: gross, origin_sacks: "6", origin_humidity_percent: "51", origin_damage_percent: "", batch_ids: [ "", batch.id.to_s ], **extra
    } }
  end

  before do
    SiteSetting.instance.update!(shrink_tolerance_percent: 1, weight_tolerance_percent: 1)
    sign_in admin
  end

  it "asks the shrink's reason in «Nueva salida» when its lots and local scale differ over the tolerance" do
    # (900 − 6) × 0.49 = 438.06: 9.97 % less than its lots
    ship("900")
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Motivo de la merma falta: la báscula local difiere 9.97 % de las compras de sus lotes y la tolerancia es 1 %")
    expect(page.at_css("[data-shrink-reason-field] textarea")).to be_present

    ship("900", shrink_reason: "Café húmedo, se oreó en la bodega")
    shipment = Shipment.last
    expect(shipment.shrink_reason).to eq("Café húmedo, se oreó en la bodega")
    expect(shipment.missing_reasons).to be_empty
  end

  it "asks nothing within the tolerance, or without one" do
    # (990 − 6) × 0.49 = 482.16: 0.91 %
    ship("990")
    expect(Shipment.last.shrink_reason).to be_nil

    SiteSetting.instance.update!(shrink_tolerance_percent: nil)
    batch.update!(shipment: nil)
    Shipment.last.void!(admin)
    ship("900")
    expect(Shipment.last.missing_reasons).to be_empty
  end

  it "asks the difference's reason when weighing at the buyer's, and shows both on the detail and the reconciliation" do
    ship("990")
    shipment = Shipment.last
    arrival = { received_on: Time.zone.today, weight_note_number: "N1", destination_gross_weight: "950", destination_sacks: "6",
                destination_humidity_percent: "51", destination_damage_percent: "" }

    get edit_sales_shipment_arrival_path(shipment)
    expect(page.at_css("[data-weighing-calculator-target='reasonField']").key?("hidden")).to be(true)
    patch sales_shipment_arrival_path(shipment), params: { shipment: arrival }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Motivo de la diferencia con el comprador falta: la báscula del comprador difiere")
    expect(page.at_css("[data-weighing-calculator-target='reasonField']").key?("hidden")).to be(false)

    patch sales_shipment_arrival_path(shipment), params: { shipment: arrival.merge(difference_reason: "Su báscula pesa de menos") }
    expect(shipment.reload).to have_attributes(status: "received", difference_reason: "Su báscula pesa de menos")

    get sales_shipment_path(shipment)
    expect(page.at_css("[data-reason='difference']").text).to eq("Su báscula pesa de menos")
    get sales_stock_reconciliation_path(date: Time.zone.today)
    expect(page.at_css("#reconciliation_shipment_#{shipment.id} [data-reason='difference']").text).to include("Su báscula pesa de menos")
  end

  it "warns on the detail when lots added later pass the tolerance, and takes the reason there, also sold" do
    shipment = create(:shipment, origin_gross_weight: 900, buyer:)
    post sales_shipment_batches_path(shipment), params: { batch_ids: [ batch.id ] }
    expect(shipment.reload.coffee_batches).to eq([ batch ])
    expect(shipment.missing_reasons).to eq([ :shrink ])

    get sales_shipment_path(shipment)
    expect(page.at_css("[data-reason='shrink']").text).to include("Falta")
    expect(page.css("[data-shipment-reasons] a").map(&:text)).to include("Anotar motivo")

    shipment.update!(receiving: true, received_on: Time.zone.today, destination_gross_weight: 900, destination_sacks: 6, destination_humidity_percent: 51)
    create(:sale, buyer:, shipments: [ shipment ], user: admin)
    get edit_sales_shipment_reasons_path(shipment)
    expect(page.at_css("[data-reason-shrink]").text).to include("9.97 %")
    patch sales_shipment_reasons_path(shipment), params: { shipment: { shrink_reason: "Se oreó" } }
    expect(shipment.reload.shrink_reason).to eq("Se oreó")
    expect(shipment.missing_reasons).to be_empty

    get sales_shipment_path(shipment)
    expect(page.css("[data-shipment-reasons] a").map(&:text)).to include("Cambiar motivos")
  end

  it "lets who edits Salidas write them, not a voided shipment" do
    reader = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "shipments", can_read: true) }
    shipment = create(:shipment, buyer:)
    sign_in reader
    get edit_sales_shipment_reasons_path(shipment)
    expect(response).to redirect_to(root_path)

    sign_in admin
    shipment.void!(admin)
    patch sales_shipment_reasons_path(shipment), params: { shipment: { shrink_reason: "x" } }
    expect(shipment.reload.shrink_reason).to be_nil
  end
end
