require "rails_helper"

# What a shipment cost (Fernando, 2026-11-12), on screen: the invoices are
# filtered in place, marked and linked; a cost shows its amount as it is typed.
RSpec.describe "Shipment cost", type: :system do
  let(:admin) { create(:user, :admin) }

  def invoice_for(name)
    producer = create(:producer, person: create(:person, first_names: name, last_names: "Zelaya"))
    purchase = create(:purchase, producer:)
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
  end

  it "filters, marks and links invoices, then registers a cost per quintal" do
    ana = invoice_for("Ana")
    invoice_for("Bruno")
    shipment = create(:shipment)
    sign_in_as(admin)

    visit sales_shipment_path(shipment)
    expect(page).to have_css("[data-cost-missing]")
    click_link "Elegir facturas"
    expect(page).to have_css("[data-shipment-invoice-choices] tbody tr", count: 2)
    page.execute_script("document.body.dataset.pageMarker = 'still here'")

    fill_in "Buscar", with: "Ana"
    expect(page).to have_css("[data-shipment-invoice-choices] tbody tr", count: 1)
    expect(page.evaluate_script("document.body.dataset.pageMarker")).to eq("still here")
    expect(page).to have_button("Ligar a la salida", disabled: true)
    check "Marcar la factura #{ana.display_number}"
    expect(page).to have_text("Facturas marcadas: 1")
    click_button "Ligar a la salida"

    expect(page).to have_css(".toast", text: "1 factura ligada a la salida.")
    expect(page).to have_no_css("[data-cost-missing]")
    within("[data-shipment-invoices]") { expect(page).to have_text("Ana Zelaya") }

    click_link "Registrar gasto"
    within("dialog[open]") do
      select "Carga y descarga", from: "Concepto"
      choose "Por quintal"
      choose "De la báscula local"
      choose "Netas"
      fill_in "Precio (L)", with: "10"
      expected = (shipment.origin_net_weight / 100 * 10).round(2)
      expect(page).to have_text("L #{ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", expected))}")
      select "Efectivo", from: "Forma de pago"
      click_button "Registrar gasto"
    end
    expect(page).to have_css(".toast", text: "Gasto de")
    expect(shipment.costs.count).to eq(1)
  end
end
