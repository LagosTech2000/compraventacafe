require "rails_helper"

# Administrators void a paid purchase invoice from its window, and edit a
# collected sale with the same live preview as «Nueva venta» (Fernando, 2026-11-12).
RSpec.describe "Admin edits of invoices and sales", type: :system do
  let(:admin) { create(:user, :admin) }

  it "voids a paid invoice with its reason" do
    producer = create(:producer)
    invoice = InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ create(:purchase, producer:).id ], payment_status: "paid",
                                payment_method: "cash").call.invoice
    sign_in_as(admin)
    visit trading_invoice_path(invoice)
    click_link "Anular factura"
    within("dialog[open]") do
      expect(page).to have_text("Su abono de")
      fill_in "Motivo de la anulación", with: "Productor equivocado"
      click_button "Anular factura"
    end
    expect(page).to have_css(".toast", text: "Factura #{invoice.display_number} anulada.")
    expect(page).to have_css("[data-invoice-voided]", text: "Productor equivocado")
    expect(invoice.reload).to be_voided
  end

  it "edits a collected sale's price with the live preview" do
    buyer = create(:buyer)
    shipment = create(:shipment, :received, buyer:)
    sale = SaleIssuer.new(buyer:, user: admin, shipment_ids: [ shipment.id ], sale: { price_unit: "pound", unit_price: "50", quintal_pounds: "120" },
                          payment_status: "paid", payment_method: "cash").call.sale
    sign_in_as(admin)
    visit sales_sale_path(sale)
    click_link "Editar venta"
    fill_in "sale_unit_price", with: "40"
    expected = (shipment.destination_net_weight * 40).round(2)
    expect(page).to have_css("[data-sale-builder-target='total']", text: ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", expected)))
    click_button "Guardar cambios"
    expect(page).to have_css(".toast", text: "Venta actualizada.")
    expect(page).to have_css("[data-sale-overpaid]")
    expect(sale.reload.total).to eq(expected)
  end
end
