require "rails_helper"

# Paying invoices on screen: the payment fields when invoicing
# (invoice_payment_choice_controller.js) and a payment ("abono") registered
# from the invoice in a modal, whose receipt opens right after.
RSpec.describe "Invoice payments", type: :system do
  let(:user) { create(:user, :admin) }
  let(:producer) { create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")) }

  before { sign_in_as(user) }

  it "shows only the payment fields that apply when invoicing" do
    create(:purchase, producer:)
    visit new_trading_invoice_path(producer_id: producer.id)

    expect(page).to have_select("invoice_payment_status", selected: "Pendiente de pago")
    expect(page).to have_no_field("invoice_amount")
    expect(page).to have_no_select("invoice_payment_method")

    select "Cancelada", from: "invoice_payment_status"
    expect(page).to have_select("invoice_payment_method")
    expect(page).to have_no_field("invoice_amount")

    select "Pago parcial", from: "invoice_payment_status"
    fill_in "invoice_amount", with: "1000"
    select "Efectivo", from: "invoice_payment_method"
    click_button "Crear factura"

    expect(page).to have_text("Factura creada.")
    expect(page).to have_css("article", text: "Pago parcial")
    expect(Invoice.last).to have_attributes(payment_status: "partial", balance_due: BigDecimal("3120.90"))
  end

  it "registers a payment from the invoice and opens its receipt" do
    invoice = InvoiceIssuer.new(producer:, user:, purchase_ids: [ create(:purchase, producer:).id ], payment_status: "pending").call.invoice
    visit trading_invoice_path(invoice)

    click_link "Registrar abono"
    within("dialog[open]") do
      expect(page).to have_field("invoice_payment_amount", with: "4120.9")
      fill_in "invoice_payment_amount", with: "1500"
      select "Transferencia", from: "invoice_payment_payment_method"
      click_button "Registrar abono"
    end

    expect(page).to have_text("Abono registrado.")
    within("dialog[open]") { expect(page).to have_text("Recibo de pago", wait: 5).and have_text(/Saldo pendiente\s+L 2,620.90/) }
    expect(invoice.reload).to be_partial
  end
end
