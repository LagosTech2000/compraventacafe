require "rails_helper"

# A lot closed without a shipment or a process (Fernando, 2026-11-22: lot
# 27's invoices never went on a shipment): not offered anymore, its
# purchases still count for the producers' QQ; when its coffee is gone, a
# count adjustment takes it out of the stock. Administrators only.
RSpec.describe "Closing a lot without a shipment" do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer) }
  let(:warehouse) { Warehouse.main! }

  def page = Nokogiri::HTML(response.body)
  def stock = CoffeeStock.new(warehouse:).row("wet_parchment")

  def invoice_of(purchase)
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
  end

  let!(:lot) do
    create(:coffee_batch).tap { it.batch_invoices.create!(invoice: invoice_of(create(:purchase, producer:, gross_weight: 600, purchased_at: 2.days.ago)), percent: 100, created_by: admin) }
  end

  before do
    create(:purchase, gross_weight: 400, purchased_at: 3.days.ago)
    sign_in admin
  end

  it "takes its coffee out of the stock when it is gone, and stops offering it" do
    quintals = ProducerProfile.new(producer).season_quintals
    expect(stock.gross_stock).to eq(1_000)

    post sales_coffee_batch_closing_path(lot), params: { close_reason: "Salió sin registrarse", gone: "1" }
    lot.reload
    expect(lot).to be_closed
    expect(lot).to have_attributes(closed_by: admin, close_reason: "Salió sin registrarse")
    expect(lot.stock_count).to have_attributes(counted_gross: 400, gross_weight: -600, reason: "other")
    expect(stock.gross_stock).to eq(400)
    expect(ProducerProfile.new(producer).season_quintals).to eq(quintals)

    get new_sales_shipment_path
    expect(page.at_css("#coffee_batch_#{lot.id}, [value='#{lot.id}'][name*='batch_ids']")).to be_nil
    expect(CoffeeBatch.free).not_to include(lot)

    get sales_coffee_batch_path(lot)
    expect(response.body).to include("Cerrado sin salida", lot.stock_count.label)

    delete sales_coffee_batch_closing_path(lot)
    expect(lot.reload).not_to be_closed
    expect(stock.gross_stock).to eq(1_000)
  end

  it "only hides it when its coffee is still counted as it is" do
    post sales_coffee_batch_closing_path(lot), params: { close_reason: "Ya se corrigió con un conteo" }
    expect(lot.reload).to be_closed
    expect(lot.stock_count).to be_nil
    expect(stock.gross_stock).to eq(1_000)

    shipment = build(:shipment, batch_ids: [ lot.id ])
    expect(shipment).not_to be_valid
    expect(shipment.errors.full_messages.to_sentence).to include("está cerrado sin salida")
    expect(lot.batch_invoices.first.invoice.void_blockers.map(&:first)).to include(:lot_closed)
  end

  it "asks the reason, and is for administrators only", :all_records do
    post sales_coffee_batch_closing_path(lot), params: { close_reason: " " }
    expect(response).to have_http_status(:unprocessable_content)
    expect(lot.reload).not_to be_closed

    seller = create(:user).tap { create(:permission, user: it, module_key: "sales", can_read: true, can_create: true, can_update: true, can_destroy: true) }
    sign_in seller
    get sales_coffee_batch_path(lot)
    expect(response.body).not_to include("Cerrar lote")
    post sales_coffee_batch_closing_path(lot), params: { close_reason: "x", gone: "1" }
    expect(lot.reload).not_to be_closed
  end
end
