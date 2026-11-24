require "rails_helper"

# «Liquidar salida» (Fernando, 2026-11-18: every sale has one shipment): the
# buyer's scale, the sale on that weight and its collection, in one screen,
# all or none.
RSpec.describe "Shipment settled at the buyer's" do
  let(:admin) { create(:user, :admin) }
  let(:buyer) { create(:buyer) }
  let(:account) { create(:money_account, opening_balance: 0) }
  let(:shipment) { create(:shipment, buyer:, departed_at: 1.day.ago) }
  let(:arrival) do
    { received_on: Time.zone.today, weight_note_number: "N-77", destination_gross_weight: "980", destination_sacks: "12",
      destination_humidity_percent: "51", destination_damage_percent: "1" }
  end

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "offers it from the detail and saves the weight, the sale and its collection together" do
    get sales_shipment_path(shipment)
    expect(page.css("a").map(&:text)).to include("Liquidar salida")
    get edit_sales_shipment_arrival_path(shipment, open_settle: 1)
    expect(page.at_css("details#settle")["open"]).not_to be_nil
    expect(page.at_css("button[name=settle_now]").text).to eq("Guardar y liquidar")

    patch sales_shipment_arrival_path(shipment), params: { shipment: arrival, settle_now: "1", settle: {
      price_unit: "quintal", quintal_pounds: "120", unit_price: "6000", buyer_document_number: "Comprobante 9",
      payment_status: "paid", payment_method: "transfer", money_account_id: account.id
    } }
    sale = Sale.last
    # (980 − 6) × 0.49 × 0.99 = 472.49 lb ÷ 120 × L 6,000
    expect(sale).to have_attributes(total: BigDecimal("23624.50"), sold_on: Time.zone.today, payment_status: "paid", buyer_document_number: "Comprobante 9")
    expect(sale.payments.sole).to have_attributes(amount: BigDecimal("23624.50"), money_account: account)
    expect(shipment.reload).to have_attributes(status: "sold", weight_note_number: "N-77")
    expect(flash[:notice]).to eq("Remisión #{shipment.display_number} liquidada: quedó en la venta #{sale.display_number}.")
  end

  it "saves nothing when the sale fails, and keeps what was written" do
    patch sales_shipment_arrival_path(shipment), params: { shipment: arrival, settle_now: "1", settle: { price_unit: "quintal", quintal_pounds: "120", unit_price: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Sale.count).to eq(0)
    expect(shipment.reload).to have_attributes(received_on: nil, destination_net_weight: nil)
    expect(page.at_css("input#shipment_weight_note_number")["value"]).to eq("N-77")
    expect(page.at_css("details#settle")["open"]).not_to be_nil

    patch sales_shipment_arrival_path(shipment), params: { shipment: arrival }
    expect(shipment.reload.status).to eq("received")
    expect(Sale.count).to eq(0)
  end

  it "is only for who can sell" do
    weigher = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "shipments", can_read: true, can_update: true) }
    sign_in weigher
    get edit_sales_shipment_arrival_path(shipment)
    expect(page.at_css("details#settle")).to be_nil
    patch sales_shipment_arrival_path(shipment), params: { shipment: arrival, settle_now: "1", settle: { price_unit: "pound", unit_price: "50" } }
    expect(shipment.reload.status).to eq("received")
    expect(Sale.count).to eq(0)
  end
end
