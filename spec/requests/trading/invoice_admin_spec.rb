require "rails_helper"

# A purchase invoice is never edited, by anyone (Fernando, 2026-11-18): an
# administrator voids it, with a reason, once nothing after it depends on
# it (its payments removed, no pago con café, no lot that left); its
# purchases are voided with it. Before (2026-11-12) an administrator edited
# it, its purchases and its payments, and voided it paid.
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

  it "voids a paid invoice only after its payments are removed, with a reason, out of every list and total" do
    expect(invoice).to be_paid
    expect(AccountBalance.new.for(account)).to eq(50_000 - invoice.total)
    sign_in admin

    get new_trading_invoice_void_path(invoice)
    expect(page.at_css("[data-void-blockers]").text).to include("Tiene un abono: quítalo antes de anular la factura.")
    expect(page.at_css("input[type=submit][disabled]")).to be_present
    post trading_invoice_void_path(invoice), params: { invoice: { void_reason: "Se facturó a otro productor" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(invoice.reload).not_to be_voided

    delete trading_invoice_payment_path(invoice, invoice.payments.sole)
    expect(AccountBalance.new.for(account)).to eq(50_000)
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
    # Every state, voided too (Fernando, 2026-11-13).
    get trading_invoices_path(payment_status: "all")
    expect(page.css("[id$='invoice_#{invoice.id}']")).to be_present
    expect(page.at_css("select#payment_status option[value='']").text).to eq("Todas, sin las anuladas")
    get trading_invoice_path(invoice)
    expect(page.at_css("[data-invoice-voided]").text).to include("Se facturó a otro productor")
  end

  it "does not void while a purchase paid a loan or a lot of it left, and takes the invoice off its free lots" do
    loan = create(:loan, person: producer.person, cash_amount: 100, monthly_interest_rate: 0)
    pending = InvoiceIssuer.new(producer:, user: admin, purchase_ids: purchases.map(&:id), payment_status: "pending").call.invoice
    create(:loan_payment, loan:, purchase: purchases.first, amount: 50, payment_method: "coffee")
    sign_in admin
    post trading_invoice_void_path(pending), params: { invoice: { void_reason: "Error" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("pago con café")

    LoanPayment.delete_all
    batch = create(:coffee_batch, coffee_state: purchases.first.coffee_state)
    batch.batch_invoices.create!(invoice: pending, percent: 100, created_by: admin)
    shipment = create(:shipment, coffee_state: batch.coffee_state, warehouse: batch.warehouse)
    batch.update!(shipment:)
    post trading_invoice_void_path(pending), params: { invoice: { void_reason: "Error" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("ya salió en la remisión #{shipment.display_number}")

    batch.update!(shipment: nil)
    post trading_invoice_void_path(pending), params: { invoice: { void_reason: "Error" } }
    expect(pending.reload).to be_voided
    expect(batch.batch_invoices.reload).to be_empty
  end

  it "has no edit, and leaves invoiced purchases and payments as they were, for an administrator too" do
    invoice
    sign_in admin
    get trading_invoice_path(invoice)
    expect(page.css("a").map(&:text)).not_to include("Editar factura", "Editar")
    expect(Invoice.method_defined?(:revise!)).to be(false)

    purchase = purchases.first.reload
    get edit_trading_purchase_path(purchase)
    expect(response).to redirect_to(root_path)
    expect(purchase.update(price_per_pound: 10)).to be(false)
    expect(purchase.errors.full_messages.join).to include("Una compra facturada no se edita")

    payment = invoice.payments.sole
    expect(payment.update(amount: 1)).to be(false)
    expect(payment.errors.full_messages.join).to include("Un abono no se edita")
  end

  it "removes only the latest payment, for an administrator too" do
    pending = InvoiceIssuer.new(producer:, user: admin, purchase_ids: purchases.map(&:id), payment_status: "pending").call.invoice
    first = pending.payments.create!(amount: 100, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)
    last = pending.payments.create!(amount: 200, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)
    sign_in admin

    delete trading_invoice_payment_path(pending, first)
    expect(pending.payments.reload.size).to eq(2)
    delete trading_invoice_payment_path(pending, last)
    expect(pending.payments.reload.map(&:amount)).to eq([ 100 ])
  end

  it "is for administrators only, even with every permission of Compra de café" do
    sign_in clerk
    post trading_invoice_void_path(invoice), params: { invoice: { void_reason: "x" } }
    expect(invoice.reload).not_to be_voided
    get edit_trading_purchase_path(purchases.first)
    expect(response).to redirect_to(root_path)
    get trading_invoice_path(invoice)
    expect(page.css("a").map(&:text)).not_to include("Anular factura")
  end
end
