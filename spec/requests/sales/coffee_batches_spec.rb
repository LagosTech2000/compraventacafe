require "rails_helper"

# Lots of purchased coffee (Fernando, 2026-11-13): shares of purchase
# invoices of one coffee state in one warehouse, up to a limit of gross
# pounds; they go on shipments instead of invoices. The shipment takes their
# coffee from the stock, and its shrink is what their purchases say − its
# local scale.
RSpec.describe "Lots of purchased coffee" do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")) }

  def page = Nokogiri::HTML(response.body)

  def invoice_of(*purchases)
    InvoiceIssuer.new(producer: purchases.first.producer, user: admin, purchase_ids: purchases.map(&:id), payment_status: "pending").call.invoice
  end

  before { sign_in admin }

  it "is made with a limit, then takes shares of invoices without passing 100 % of each nor its limit" do
    big = invoice_of(create(:purchase, producer:, gross_weight: 1_000))
    small = invoice_of(create(:purchase, producer:, gross_weight: 200))
    cherry = invoice_of(create(:purchase, producer:, coffee_state: "cherry"))

    post sales_coffee_batches_path, params: { coffee_batch: { batched_on: Time.zone.today, coffee_state: "wet_parchment",
                                                              warehouse_id: Warehouse.main!.id, gross_limit: "700" } }
    batch = CoffeeBatch.last
    expect(batch).to have_attributes(number: 1, gross_limit: 700, created_by: admin)
    expect(response).to redirect_to(new_sales_coffee_batch_invoice_path(batch))

    get new_sales_coffee_batch_invoice_path(batch)
    expect(page.css("[data-batch-invoice-choices] tbody tr").map { it["id"] }).to contain_exactly("choice_invoice_#{big.id}", "choice_invoice_#{small.id}")
    expect(page.at_css("[data-batch-room]").text.squish).to include("caben 700.00 lb brutas")

    post sales_coffee_batch_invoices_path(batch), params: { shares: { big.id => { chosen: "1", percent: "80" } } }
    expect(flash[:alert]).to include("pasa del límite del lote: caben 700.00 lb brutas")
    expect(batch.batch_invoices).to be_empty

    post sales_coffee_batch_invoices_path(batch), params: { shares: { big.id => { chosen: "1", percent: "50" }, small.id => { chosen: "1", percent: "100" },
                                                                      cherry.id => { chosen: "0", percent: "100" } } }
    expect(response).to redirect_to(sales_coffee_batch_path(batch))
    batch.reload
    expect(batch.batch_invoices.map { [ it.invoice, it.percent ] }).to contain_exactly([ big, 50 ], [ small, 100 ])
    expect(batch.gross_weight).to eq(700)
    expect(batch.net_weight).to eq(((big.net_weight / 2) + small.net_weight).round(2))
    expect(batch.room).to eq(0)

    # The other half of the big invoice goes to another lot, never more.
    other = create(:coffee_batch, gross_limit: 2_000)
    expect(other.batch_invoices.create(invoice: big, percent: 60, created_by: admin).errors[:percent].join).to include("pasa de lo libre de la factura (50 %)")
    expect(other.batch_invoices.create(invoice: big, percent: 50, created_by: admin)).to be_persisted
    get new_sales_coffee_batch_invoice_path(create(:coffee_batch))
    expect(page.css("[data-batch-invoice-choices] tbody tr")).to be_empty

    get sales_coffee_batch_path(batch)
    expect(page.at_css("[data-batch='gross'] dd").text.strip).to eq("700.00")
    expect(page.css("[data-batch-invoices] tbody tr").size).to eq(2)
    get sales_coffee_batches_path
    expect(page.css("[data-coffee-batches] tbody tr").size).to eq(3)
  end

  it "goes on a shipment, which takes its coffee from the stock, and gives its shrink" do
    purchase = create(:purchase, producer:, gross_weight: 1_000, humidity_percent: 51, purchased_at: 1.hour.ago) # (1,000 − 7) × 0.49 = 486.57 net
    older = create(:purchase, gross_weight: 500, purchased_at: 2.days.ago)
    invoice = invoice_of(purchase)
    batch = create(:coffee_batch, gross_limit: 1_000)
    batch.batch_invoices.create!(invoice:, percent: 100, created_by: admin)
    stock_before = CoffeeStock.new.row("wet_parchment").stock

    post sales_shipments_path, params: { shipment: {
      buyer_id: create(:buyer).id, departed_at: Time.current, coffee_state: "wet_parchment", warehouse_id: Warehouse.main!.id,
      origin_gross_weight: "990", origin_sacks: "6", origin_humidity_percent: "51", origin_damage_percent: "", batch_ids: [ "", batch.id.to_s ]
    } }
    shipment = Shipment.last
    expect(shipment.coffee_batches).to eq([ batch ])
    expect(batch.reload.shipment).to eq(shipment)

    # The lot's coffee leaves the stock, from its purchase, not the oldest.
    expect(shipment.stock_net_weight).to eq(purchase.net_weight)
    expect(CoffeeStock.new.row("wet_parchment").stock).to eq(stock_before - purchase.net_weight)
    lots = CoffeeLots.new
    expect(lots.portions_for(shipment).map { it.lot.source }).to eq([ purchase ])
    expect(lots.lots(coffee_state: "wet_parchment").map(&:source)).to eq([ older ])

    # Shrink: the purchases − the local scale, gross and net.
    expect(shipment.shrink_gross).to eq(10)
    expect(shipment.shrink_net).to eq(purchase.net_weight - shipment.origin_net_weight)
    get sales_shipment_path(shipment)
    expect(page.at_css("[data-shrink-gross]").text.strip).to eq("+10.00 lb")

    get sales_shipments_path(shrink: "loss")
    expect(page.css("[data-shrink]").map { it.text.squish }.first).to include("+10.00 lb")
    get sales_shipments_path(shrink: "gain")
    expect(response.body).not_to include("id=\"shipment_#{shipment.id}\"")
    get sales_shipments_path(shrink: "no_batches")
    expect(response.body).not_to include("id=\"shipment_#{shipment.id}\"")

    get sales_root_path
    expect(page.at_css("[data-shrink='loss'] dd").text.strip).to eq("+10.00 lb")
    expect(page.at_css("[data-shrink='loss'] a")["href"]).to eq(sales_shipments_path(shrink: "loss", season_year: Season.current.year))

    # Without its lot, it goes back to its local scale, the oldest first.
    delete sales_shipment_batch_path(shipment, batch)
    expect(batch.reload.shipment).to be_nil
    expect(shipment.reload.stock_net_weight).to eq(shipment.origin_net_weight)
    expect(shipment.shrink_gross).to be_nil
  end

  it "only takes free lots of the shipment's coffee state and warehouse" do
    shipment = create(:shipment)
    fits = create(:coffee_batch)
    cherry = create(:coffee_batch, coffee_state: "cherry")
    taken = create(:coffee_batch, shipment: create(:shipment))

    get new_sales_shipment_batch_path(shipment)
    expect(page.css("[data-coffee-batches] tbody tr").map { it["id"] }).to eq([ "coffee_batch_#{fits.id}" ])
    post sales_shipment_batches_path(shipment), params: { batch_ids: [ fits.id, cherry.id, taken.id ] }
    expect(shipment.reload.coffee_batches).to eq([ fits ])

    expect(shipment.update(batch_ids: [ cherry.id ])).to be(false)
    expect(shipment.errors.full_messages.join).to include("es de otro estado del café")
  end

  it "comes back to «Nueva salida» from its window once its invoices are in" do
    invoice = invoice_of(create(:purchase, producer:))
    post sales_coffee_batches_path, params: { picker: "1", coffee_batch: { batched_on: Time.zone.today, coffee_state: "wet_parchment",
                                                                           warehouse_id: Warehouse.main!.id, gross_limit: "5000" } },
                                    headers: { "Turbo-Frame" => "modal" }
    batch = CoffeeBatch.last
    expect(response).to redirect_to(new_sales_coffee_batch_invoice_path(batch, picker: "1"))

    post sales_coffee_batch_invoices_path(batch), params: { picker: "1", shares: { invoice.id => { chosen: "1", percent: "100" } } },
                                                  headers: { "Turbo-Frame" => "modal" }
    result = page.at_css("[data-controller='modal-result']")
    expect(result["data-modal-result-event-value"]).to eq("coffee_batch:created")
    expect(JSON.parse(result["data-modal-result-detail-value"])).to include("id" => batch.id, "label" => "Lote 0001", "coffee_state" => "wet_parchment")
  end

  it "changes on a sold shipment only by an administrator (Fernando, 2026-11-13)", :all_records do
    shipment = create(:sale).shipments.first
    invoice = invoice_of(create(:purchase, producer:))
    other = invoice_of(create(:purchase, producer:))
    batch = create(:coffee_batch, warehouse: shipment.warehouse, coffee_state: shipment.coffee_state, gross_limit: 10_000)
    batch.batch_invoices.create!(invoice:, percent: 100, created_by: admin)
    batch.update!(shipment:)
    free = create(:coffee_batch, warehouse: shipment.warehouse, coffee_state: shipment.coffee_state)

    seller = create(:user).tap { create(:permission, user: it, module_key: "sales", can_read: true, can_create: true, can_update: true, can_destroy: true) }
    create(:permission, user: seller, module_key: "trading", submodule_key: "invoices", can_read: true)
    sign_in seller
    patch sales_coffee_batch_path(batch), params: { coffee_batch: { gross_limit: "9000" } }
    expect(batch.reload.gross_limit).to eq(10_000)
    post sales_coffee_batch_invoices_path(batch), params: { shares: { other.id => { chosen: "1", percent: "50" } } }
    expect(batch.reload.batch_invoices.size).to eq(1)
    post sales_shipment_batches_path(shipment), params: { batch_ids: [ free.id ] }
    expect(free.reload.shipment).to be_nil
    Current.session = seller.sessions.last
    expect(batch.batch_invoices.create(invoice: other, percent: 50, created_by: seller).errors.full_messages.join).to include("solo un administrador")

    sign_in admin
    Current.session = admin.sessions.last
    patch sales_coffee_batch_path(batch), params: { coffee_batch: { gross_limit: "9000" } }
    expect(batch.reload.gross_limit).to eq(9_000)
    post sales_coffee_batch_invoices_path(batch), params: { shares: { other.id => { chosen: "1", percent: "50" } } }
    expect(batch.reload.batch_invoices.map(&:invoice)).to contain_exactly(invoice, other)
    post sales_shipment_batches_path(shipment), params: { batch_ids: [ free.id ] }
    expect(free.reload.shipment).to eq(shipment)
    delete sales_shipment_batch_path(shipment, free)
    expect(free.reload.shipment).to be_nil
    get sales_shipment_path(shipment)
    expect(response.body).to include(new_sales_shipment_batch_path(shipment))
  ensure
    Current.reset
  end

  it "frees its invoices' share when an invoice is voided" do
    invoice = invoice_of(create(:purchase, producer:))
    batch = create(:coffee_batch)
    batch.batch_invoices.create!(invoice:, percent: 100, created_by: admin)
    invoice.void!(admin, reason: "Error")
    expect(batch.reload.batch_invoices).to be_empty
  end

  it "shows the invoices of a lot only to who reads them", :all_records do
    batch = create(:coffee_batch)
    reader = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "shipments", can_read: true) }
    sign_in reader
    get sales_coffee_batch_path(batch)
    expect(response.body).to include(I18n.t("sales.coffee_batches.show.invoices_hidden"))
    get new_sales_coffee_batch_invoice_path(batch)
    expect(response).to redirect_to(root_path)
  end
end
