require "rails_helper"

# «Guardar, facturar y pagar» (Fernando, 2026-11-18): they buy, invoice and
# pay at once; the purchase, its invoice and its payment, all or none.
RSpec.describe "Purchase saved, invoiced and paid at once" do
  let(:clerk) do
    create(:user).tap { create(:permission, user: it, module_key: "trading", can_read: true, can_create: true, can_update: true, can_destroy: true) }
  end
  let(:producer) { create(:producer) }
  let(:account) { create(:money_account, opening_balance: 50_000) }

  def page = Nokogiri::HTML(response.body)
  def purchase_params = attributes_for(:purchase).merge(producer_id: producer.id, hauler_choice: "none")

  before { sign_in clerk }

  it "offers the button in «Nueva compra» and saves the purchase with its paid invoice" do
    get new_trading_purchase_path
    expect(page.at_css("button[name=settle_now]").text).to eq("Guardar, facturar y pagar")
    expect(page.at_css("[data-settle-fields] select#settle_payment_method")).to be_present

    post trading_purchases_path, params: { purchase: purchase_params, settle_now: "1", settle: { payment_method: "cash", money_account_id: account.id } }
    purchase = Purchase.last
    invoice = purchase.invoice
    expect(invoice).to have_attributes(payment_status: "paid", created_by: clerk)
    expect(invoice.payments.sole).to have_attributes(amount: purchase.total, payment_method: "cash", money_account: account)
    expect(AccountBalance.new.for(account)).to eq(50_000 - purchase.total)
    expect(flash[:notice]).to include("Quedó en la factura #{invoice.display_number}, pagada.")
  end

  it "saves nothing without a payment method, and keeps what was written" do
    expect do
      post trading_purchases_path, params: { purchase: purchase_params.merge(observations: "Lote del cerro"), settle_now: "1", settle: { payment_method: "" } }
    end.not_to change(Purchase, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(Invoice.count).to eq(0)
    expect(page.at_css("textarea#purchase_observations").text.strip).to eq("Lote del cerro")
    expect(page.at_css("button[name=settle_now]")).to be_present
  end

  it "only saves the purchase with «Guardar», and leaves the button out without invoicing" do
    post trading_purchases_path, params: { purchase: purchase_params, settle: { payment_method: "cash" } }
    expect(Purchase.last.invoice).to be_nil

    reader = create(:user).tap { create(:permission, user: it, module_key: "trading", submodule_key: "purchases", can_read: true, can_create: true) }
    sign_in reader
    get new_trading_purchase_path
    expect(page.at_css("button[name=settle_now]")).to be_nil
    post trading_purchases_path, params: { purchase: purchase_params, settle_now: "1", settle: { payment_method: "cash" } }
    expect(Purchase.last.invoice).to be_nil
  end
end
