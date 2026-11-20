require "rails_helper"

# Closed records are not edited, by anyone (Fernando, 2026-11-18): an
# administrator voids a paid invoice once its payments are removed, and a
# collected sale offers no edit.
RSpec.describe "Closed invoices and sales", type: :system do
  let(:admin) { create(:user, :admin) }

  it "voids a paid invoice after removing its payment, with its reason" do
    producer = create(:producer)
    invoice = InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ create(:purchase, producer:).id ], payment_status: "paid",
                                payment_method: "cash").call.invoice
    sign_in_as(admin)
    visit trading_invoice_path(invoice)
    click_link "Anular factura"
    within("dialog[open]") do
      expect(page).to have_css("[data-void-blockers]", text: "Tiene un abono: quítalo antes de anular la factura.")
      expect(page).to have_button("Anular factura", disabled: true)
      click_on "Cancelar"
    end

    accept_confirm { click_button "Quitar" }
    expect(page).to have_css(".toast", text: "Abono quitado.")
    click_link "Anular factura"
    within("dialog[open]") do
      expect(page).to have_no_css("[data-void-blockers]")
      fill_in "Motivo de la anulación", with: "Productor equivocado"
      click_button "Anular factura"
    end
    expect(page).to have_css(".toast", text: "Factura #{invoice.display_number} anulada.")
    expect(page).to have_css("[data-invoice-voided]", text: "Productor equivocado")
    expect(invoice.reload).to be_voided
  end

  it "shows a collected sale with no edit" do
    buyer = create(:buyer)
    shipment = create(:shipment, :received, buyer:)
    sale = SaleIssuer.new(buyer:, user: admin, shipment_ids: [ shipment.id ], sale: { price_unit: "pound", unit_price: "50", quintal_pounds: "120" },
                          payment_status: "paid", payment_method: "cash").call.sale
    sign_in_as(admin)
    visit sales_sale_path(sale)
    expect(page).to have_content("Venta #{sale.display_number}")
    expect(page).to have_no_link("Editar venta")
    expect(page).to have_no_link("Editar")
  end
end
