require "rails_helper"

# «¿Qué café lleva?» (Fernando, 2026-11-18): «Nueva salida» picks the
# invoices it carries and their lot is made on its own, with what is left
# of each one; all with the shipment, or nothing.
RSpec.describe "Shipment carrying invoices, its lot made on its own" do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer) }
  let(:buyer) { create(:buyer) }

  def page = Nokogiri::HTML(response.body)

  def invoice_of(*purchases)
    InvoiceIssuer.new(producer: purchases.first.producer, user: admin, purchase_ids: purchases.map(&:id), payment_status: "paid", payment_method: "cash").call.invoice
  end

  def ship(invoice_ids, gross: "990", **extra)
    post sales_shipments_path, params: { shipment: {
      buyer_id: buyer.id, departed_at: Time.current, coffee_state: "wet_parchment", warehouse_id: Warehouse.main!.id,
      origin_gross_weight: gross, origin_sacks: "6", origin_humidity_percent: "51", origin_damage_percent: "", invoice_ids: [ "", *invoice_ids.map(&:to_s) ], **extra
    } }
  end

  before { sign_in admin }

  it "lists the free invoices oldest first, and makes the lot with what is left of each" do
    older = invoice_of(create(:purchase, producer:, gross_weight: 600, purchased_at: 2.days.ago))
    newer = invoice_of(create(:purchase, producer:, gross_weight: 400, purchased_at: 1.hour.ago))
    dry = invoice_of(create(:purchase, producer:, coffee_state: "dry_parchment", humidity_percent: 12, purchased_at: 1.hour.ago))
    half = create(:coffee_batch, gross_limit: 300)
    half.batch_invoices.create!(invoice: older, percent: 50, created_by: admin)

    get new_sales_shipment_path
    rows = page.css("[data-controller~='shipment-coffee'] tbody tr")
    expect(rows.map { it["id"] }).to eq([ "coffee_invoice_#{older.id}", "coffee_invoice_#{newer.id}", "coffee_invoice_#{dry.id}" ])
    expect(rows.first.text).to include("Queda el 50 %", "300.00")

    ship([ older.id, newer.id ])
    shipment = Shipment.last
    lot = shipment.coffee_batches.sole
    expect(lot).to have_attributes(coffee_state: "wet_parchment", batched_on: Time.zone.today, created_by: admin)
    expect(lot.batch_invoices.to_h { [ it.invoice_id, it.percent ] }).to eq(older.id => 50, newer.id => 100)
    expect(lot.batch_invoices.sum(:gross_weight)).to eq(700)
    expect(CoffeeBatchInvoice.used_by_invoice([ older.id, newer.id ]).values).to all(eq(100))

    get new_sales_shipment_path
    expect(page.css("[data-controller~='shipment-coffee'] tbody tr").map { it["id"] }).to eq([ "coffee_invoice_#{dry.id}" ])
  end

  it "takes the marked lots too, and saves nothing (no lot either) when the shipment or the invoices fail" do
    invoice = invoice_of(create(:purchase, producer:, gross_weight: 1_000, purchased_at: 1.hour.ago))
    dry = invoice_of(create(:purchase, producer:, coffee_state: "dry_parchment", humidity_percent: 12, purchased_at: 1.hour.ago))

    expect { ship([ invoice.id ], buyer_id: "") }.not_to change(CoffeeBatch, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(page.at_css("#carry_invoice_#{invoice.id}")["checked"]).to be_present

    expect { ship([ dry.id ]) }.not_to change(Shipment, :count)
    expect(response.body).to include("Alguna de las facturas elegidas ya no está libre")
    expect(CoffeeBatch.count).to eq(0)

    lot = create(:coffee_batch, gross_limit: 1_000)
    ship([ invoice.id ], batch_ids: [ "", lot.id.to_s ])
    expect(Shipment.last.coffee_batches.count).to eq(2)
  end

  # A % per invoice (Fernando, 2026-11-20): at most what is left of it.
  it "takes the percent written for each invoice, never more than what is left" do
    half = invoice_of(create(:purchase, producer:, gross_weight: 600, purchased_at: 2.days.ago))
    whole = invoice_of(create(:purchase, producer:, gross_weight: 400, purchased_at: 1.hour.ago))
    create(:coffee_batch, gross_limit: 300).batch_invoices.create!(invoice: half, percent: 50, created_by: admin)

    expect { ship([ half.id ], invoice_percents: { half.id.to_s => "60" }) }.not_to change(CoffeeBatch, :count)
    expect(response.body).to include("La factura #{half.display_number} lleva un porcentaje que no sirve: entre 0.0001 y 50")

    ship([ half.id, whole.id ], invoice_percents: { half.id.to_s => "20", whole.id.to_s => "" })
    lot = Shipment.last.coffee_batches.sole
    expect(lot.batch_invoices.to_h { [ it.invoice_id, it.percent ] }).to eq(half.id => 20, whole.id => 100)
    expect(lot.batch_invoices.sum(:gross_weight)).to eq(520)
    expect(CoffeeBatchInvoice.used_by_invoice([ half.id ])[half.id]).to eq(70)
  end

  it "is not offered to who cannot add invoices to lots" do
    clerk = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "shipments", can_read: true, can_create: true, can_update: true) }
    sign_in clerk
    get new_sales_shipment_path
    expect(page.at_css("[data-controller~='shipment-coffee']")).to be_nil
  end
end
