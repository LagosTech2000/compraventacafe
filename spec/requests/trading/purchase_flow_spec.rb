require "rails_helper"

# The demo flow: register producer and purchase, invoice it, print, pay,
# and see it in the daily close.
RSpec.describe "Trading purchase flow" do
  let(:user) do
    create(:user).tap do |u|
      create(:permission, user: u, module_key: "trading", can_read: true, can_create: true, can_update: true, can_destroy: true)
    end
  end
  let(:zone) { create(:zone, name: "Buenas Noches") }

  before { sign_in user }

  it "creates a zone" do
    post trading_zones_path, params: { zone: { name: "  Pueblo  Nuevo " } }
    expect(response).to redirect_to(trading_zones_path)
    expect(Zone.last.name).to eq("Pueblo Nuevo")
  end

  it "rejects a duplicate zone regardless of case" do
    create(:zone, name: "Las Labranzas")
    post trading_zones_path, params: { zone: { name: "las labranzas" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "registers a producer from the purchase form's modal and hands it to the picker" do
    post trading_producers_path, headers: { "Turbo-Frame" => "modal" }, params: {
      picker: "1",
      producer: { kind: "intermediary", zone_id: zone.id, farm_name: "El Cerro",
                  person_attributes: { first_names: "Pedro", last_names: "Martínez", phone: "9999-0000" } }
    }
    producer = Producer.last
    expect(producer).to have_attributes(kind: "intermediary", farm_name: "El Cerro", zone: zone)
    expect(producer.person.phone).to eq("99990000")

    result = Nokogiri::HTML(response.body).at_css("turbo-frame#modal [data-controller='modal-result']")
    expect(result["data-modal-result-event-value"]).to eq("producer:created")
    expect(JSON.parse(result["data-modal-result-detail-value"])).to eq("id" => producer.id, "label" => "Pedro Martínez", "zone_id" => zone.id)
    expect(result["data-modal-result-refresh-value"]).to eq("false")
    expect(flash[:notice]).to be_nil
  end

  it "shows nested person errors in Spanish" do
    post trading_producers_path, params: { producer: { kind: "producer", person_attributes: { first_names: "", last_names: "" } } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Nombres no puede estar en blanco")
  end

  it "prefills the purchase form with the producer, its zone, today and 51% humidity" do
    producer = create(:producer, zone:)
    get new_trading_purchase_path(producer_id: producer.id)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("#purchase_producer_id")["value"]).to eq(producer.id.to_s)
    expect(page.at_css("#purchase_zone_id option[selected]").text).to eq("Buenas Noches")
    expect(page.at_css("#purchase_humidity_percent")["value"]).to eq("51")
    expect(page.at_css("#purchase_purchased_on")["value"]).to eq(Time.zone.today.iso8601)
  end

  it "registers a purchase with the calculation and who entered it" do
    producer = create(:producer)
    post trading_purchases_path, params: {
      purchase: { producer_id: producer.id, zone_id: zone.id, purchased_on: Time.zone.today, coffee_state: "wet_parchment",
                  gross_weight: "146", humidity_percent: "51", price_per_pound: "58", observations: "Pulpa" }
    }
    purchase = Purchase.last
    expect(purchase).to have_attributes(net_weight: BigDecimal("71.05"), total: BigDecimal("4120.90"), created_by: user)
    expect(response).to redirect_to(new_trading_purchase_path(detail: purchase.id))

    follow_redirect!
    frame = Nokogiri::HTML(response.body).at_css("dialog turbo-frame#modal")
    expect(frame["src"]).to eq(trading_purchase_path(purchase))
  end

  it "rejects a purchase without producer, in Spanish" do
    post trading_purchases_path, params: { purchase: { gross_weight: "146", humidity_percent: "51", price_per_pound: "58", coffee_state: "cherry", purchased_on: Time.zone.today } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Productor debe existir")
  end

  it "invoices, prints original and copy, and marks as paid" do
    producer = create(:producer, zone:)
    purchases = create_list(:purchase, 2, producer:)

    post trading_invoices_path, params: { producer_id: producer.id, invoice: { purchase_ids: purchases.map(&:id), payment_status: "pending" } }
    invoice = Invoice.last
    expect(response).to redirect_to(trading_invoice_path(invoice))

    get trading_invoice_path(invoice)
    expect(response.body).to include("ORIGINAL", "COPIA", "Compra de Café el Rey David", "Mata de Plátano, Moroceli", "Firma de quien factura")
    expect(response.body).to include("L 8,241.80")
    expect(response.body).to include("Facturado por: #{user.name}")

    patch trading_invoice_path(invoice), params: { invoice: { payment_method: "cash", paid_on: Time.zone.today } }
    expect(invoice.reload).to be_paid
  end

  it "does not let an invoiced purchase be edited" do
    purchase = create(:invoice).purchases.first
    patch trading_purchase_path(purchase), params: { purchase: { price_per_pound: 1 } }
    expect(response).to redirect_to(root_path)
    expect(purchase.reload.price_per_pound).to eq(58)
  end

  it "shows the daily close and the purchases of a date" do
    create(:purchase, purchased_on: Date.new(2026, 1, 15), gross_weight: 146)
    get trading_daily_close_path(date: "2026-01-15")
    expect(response.body).to include("15 de enero de 2026", "146.00", "L 4,120.90")
    get trading_purchases_path(date: "no-es-fecha")
    expect(response).to have_http_status(:ok)
  end

  it "keeps a read-only user from registering purchases" do
    reader = create(:user).tap { |u| create(:permission, user: u, module_key: "trading", can_read: true) }
    sign_in reader
    get trading_root_path
    expect(response.body).not_to include(new_trading_purchase_path)
    expect { post trading_purchases_path, params: { purchase: { gross_weight: 1 } } }.not_to change(Purchase, :count)
  end
end
