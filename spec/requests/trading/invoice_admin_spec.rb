require "rails_helper"

# Administrators void and edit purchase invoices, even paid ones (Fernando,
# 2026-11-12): voiding voids its purchases and removes its payments; editing
# changes its date, observations, purchases (and each purchase) and its
# payments; a total below what was paid is saved and shows as overpaid.
RSpec.describe "Purchase invoices, administrators" do
  let(:admin) { create(:user, :admin) }
  let(:clerk) { create(:user).tap { create(:permission, user: it, module_key: "trading", can_read: true, can_create: true, can_update: true, can_destroy: true) } }
  let(:producer) { create(:producer) }
  let(:account) { create(:money_account, opening_balance: 50_000) }
  let(:purchases) { [ create(:purchase, producer:), create(:purchase, producer:) ] }
  let(:invoice) do
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: purchases.map(&:id), payment_status: "paid", payment_method: "cash",
                      money_account_id: account.id).call.invoice
  end

  def page = Nokogiri::HTML(response.body)

  it "voids a paid invoice with its purchases and payments, with a reason, out of every list and total" do
    expect(invoice).to be_paid
    expect(AccountBalance.new.for(account)).to eq(50_000 - invoice.total)
    sign_in admin

    post trading_invoice_void_path(invoice), params: { invoice: { void_reason: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(invoice.reload).not_to be_voided

    post trading_invoice_void_path(invoice), params: { invoice: { void_reason: "Se facturó a otro productor" } }
    invoice.reload
    expect(invoice).to be_voided
    expect(invoice).to have_attributes(voided_by: admin, void_reason: "Se facturó a otro productor")
    expect(invoice.payments).to be_empty
    expect(invoice.purchases).to all(be_voided)
    expect(AccountBalance.new.for(account)).to eq(50_000)
    expect(MoneyMovements.new.all.select { it.source == "invoices" }).to be_empty
    expect(Invoice.unpaid).not_to include(invoice)
    expect(invoice.human_payment_status).to eq("Anulada")

    get trading_invoices_path
    expect(response.body).not_to include("id=\"invoice_#{invoice.id}\"")
    get trading_invoices_path(payment_status: "voided")
    expect(page.css("[id$='invoice_#{invoice.id}']")).to be_present
    get trading_invoice_path(invoice)
    expect(page.at_css("[data-invoice-voided]").text).to include("Se facturó a otro productor")
  end

  it "does not void while a purchase paid a loan, and takes the invoice off its shipment" do
    loan = create(:loan, person: producer.person, cash_amount: 100, monthly_interest_rate: 0)
    pending = InvoiceIssuer.new(producer:, user: admin, purchase_ids: purchases.map(&:id), payment_status: "pending").call.invoice
    create(:loan_payment, loan:, purchase: purchases.first, amount: 50, payment_method: "coffee")
    sign_in admin
    post trading_invoice_void_path(pending), params: { invoice: { void_reason: "Error" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("pago con café")

    LoanPayment.delete_all
    shipment = create(:shipment)
    shipment.shipment_invoices.create!(invoice: pending, created_by: admin)
    post trading_invoice_void_path(pending), params: { invoice: { void_reason: "Error" } }
    expect(pending.reload).to be_voided
    expect(shipment.invoices.reload).to be_empty
  end

  it "edits the date, observations and purchases of a paid invoice; a lower total shows as overpaid" do
    extra = create(:purchase, producer:)
    paid = invoice.paid_total
    sign_in admin
    get edit_trading_invoice_path(invoice)
    expect(page.css("[data-invoice-purchases] tbody tr").size).to eq(3)

    patch trading_invoice_path(invoice), params: { invoice: { issued_on: invoice.issued_on, observations: "Café de primera",
                                                              purchase_ids: [ purchases.first.id, extra.id ] } }
    expect(response).to redirect_to(trading_invoice_path(invoice))
    invoice.reload
    expect(invoice.purchases).to contain_exactly(purchases.first, extra)
    expect(purchases.last.reload.invoice).to be_nil
    expect(invoice.observations).to eq("Café de primera")

    patch trading_invoice_path(invoice), params: { invoice: { issued_on: invoice.issued_on, purchase_ids: [ purchases.first.id ] } }
    invoice.reload
    expect(invoice).to be_paid
    expect(invoice.overpaid_amount).to eq(paid - purchases.first.total)
    get trading_invoice_path(invoice)
    expect(page.at_css("[data-invoice-overpaid]")).to be_present

    patch trading_invoice_path(invoice), params: { invoice: { issued_on: invoice.issued_on + 5, purchase_ids: [ purchases.first.id ] } }
    expect(response).to have_http_status(:unprocessable_content)
    patch trading_invoice_path(invoice), params: { invoice: { issued_on: invoice.issued_on, purchase_ids: [ "" ] } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(invoice.reload.purchases).to eq([ purchases.first ])
  end

  it "edits an invoiced purchase and its invoice follows the new total" do
    invoice
    sign_in admin
    purchase = purchases.first.reload
    get edit_trading_purchase_path(purchase)
    expect(response).to have_http_status(:ok)
    patch trading_purchase_path(purchase), params: { purchase: { price_per_pound: "10", lock_version: purchase.lock_version } }
    expect(purchase.reload.price_per_pound).to eq(10)
    expect(invoice.reload).to be_paid
    expect(invoice.overpaid?).to be(true)
  end

  it "edits or removes any payment" do
    pending = InvoiceIssuer.new(producer:, user: admin, purchase_ids: purchases.map(&:id), payment_status: "pending").call.invoice
    first = pending.payments.create!(amount: 100, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)
    pending.payments.create!(amount: 200, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)
    sign_in admin

    patch trading_invoice_payment_path(pending, first), params: { invoice_payment: { amount: "150", paid_on: Time.zone.today, payment_method: "transfer" } }
    expect(first.reload).to have_attributes(amount: 150, payment_method: "transfer")
    expect(pending.reload.paid_total).to eq(350)

    patch trading_invoice_payment_path(pending, first), params: { invoice_payment: { amount: pending.amount_to_pay.to_s, paid_on: Time.zone.today, payment_method: "cash" } }
    expect(response).to have_http_status(:unprocessable_content)

    delete trading_invoice_payment_path(pending, first)
    expect(pending.payments.reload.map(&:amount)).to eq([ 200 ])
  end

  it "is for administrators only, even with every permission of Compra de café" do
    sign_in clerk
    get edit_trading_invoice_path(invoice)
    expect(response).to redirect_to(root_path)
    post trading_invoice_void_path(invoice), params: { invoice: { void_reason: "x" } }
    expect(invoice.reload).not_to be_voided
    get edit_trading_purchase_path(purchases.first)
    expect(response).to redirect_to(root_path)
    get trading_invoice_path(invoice)
    expect(page.css("a").map(&:text)).not_to include("Editar factura", "Anular factura")
  end
end
