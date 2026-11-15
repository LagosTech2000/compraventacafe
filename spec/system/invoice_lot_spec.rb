require "rails_helper"

# «Facturar compras» with a lot (Fernando, 2026-11-13: «que se pueda asignar
# el lote desde facturar o el porcentaje mostrando el cálculo live»): only
# the lots of the marked purchases' coffee state and warehouse can be
# chosen, and the percent shows its pounds and the lot's room as it changes.
RSpec.describe "Invoicing into a lot", type: :system do
  let(:admin) { create(:user, :admin) }

  it "shows what the percent takes and stops past the lot's limit" do
    producer = create(:producer)
    wet = create(:purchase, producer:, gross_weight: 1_000)
    cherry = create(:purchase, producer:, coffee_state: "cherry", gross_weight: 300, purchased_at: 1.hour.ago)
    lot = create(:coffee_batch, gross_limit: 600)
    cherry_lot = create(:coffee_batch, coffee_state: "cherry")
    sign_in_as(admin)
    visit new_trading_invoice_path(producer_id: producer.id)

    # Both purchases marked: two coffee states, no lot.
    expect(page).to have_css("output", text: "varios estados del café")
    expect(page).to have_select("invoice_coffee_batch_id", disabled: true)

    uncheck dom_id(cherry, :select)
    expect(page).to have_select("invoice_coffee_batch_id", disabled: false)
    expect(page).to have_css("#invoice_coffee_batch_id option[value='#{lot.id}']:not([disabled])", visible: :all)
    expect(page).to have_css("#invoice_coffee_batch_id option[value='#{cherry_lot.id}'][disabled]", visible: :all)
    expect(page).to have_no_field("invoice_batch_percent")

    find("#invoice_coffee_batch_id option[value='#{lot.id}']").select_option
    net = ->(percent) { ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", (wet.net_weight * percent / 100).round(2))) }
    expect(page).to have_css("output", text: "Toma 1,000.00 lb brutas · #{net.(100)} lb netas")
    expect(page).to have_css("output.text-danger", text: "Pasa del límite del lote por 400.00 lb brutas. Con 60.00 % o menos cabe.")

    fill_in "invoice_batch_percent", with: "50"
    expect(page).to have_css("output", text: "Toma 500.00 lb brutas · #{net.(50)} lb netas")
    expect(page).to have_css("output", text: "El lote tiene 600.00 lb brutas libres; con esta factura le quedan 100.00.")
    expect(page).to have_no_css("output.text-danger")

    fill_in "invoice_batch_percent", with: "70"
    click_button "Crear factura"
    expect(page).to have_current_path(new_trading_invoice_path(producer_id: producer.id))
    expect(Invoice.count).to eq(0)

    fill_in "invoice_batch_percent", with: "60"
    click_button "Crear factura"
    expect(page).to have_content("Factura 0001")
    expect(lot.batch_invoices.sole).to have_attributes(percent: 60, gross_weight: 600)
    expect(cherry.reload.invoice).to be_nil
  end

  it "edits the invoice's lot with the same live calculation, counting what it took as room" do
    producer = create(:producer)
    purchase = create(:purchase, producer:, gross_weight: 1_000)
    extra = create(:purchase, producer:, gross_weight: 400)
    invoice = InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
    lot = create(:coffee_batch, gross_limit: 700)
    lot.batch_invoices.create!(invoice:, percent: 50, created_by: admin)
    sign_in_as(admin)
    visit edit_trading_invoice_path(invoice)

    expect(page).to have_select("invoice_coffee_batch_id", selected: "#{lot.label} · Pergamino húmedo · Bodega 1 · caben 700.00 lb brutas")
    expect(page).to have_field("invoice_batch_percent", with: "50")
    expect(page).to have_css("output", text: "El lote tiene 700.00 lb brutas libres; con esta factura le quedan 200.00.")

    # The extra purchase marked: the same percent takes more.
    find("input[name='invoice[purchase_ids][]'][value='#{extra.id}']").check
    expect(page).to have_css("output", text: "Toma 700.00 lb brutas")
    expect(page).to have_css("output", text: "le quedan 0.00")

    fill_in "invoice_batch_percent", with: "60"
    expect(page).to have_css("output.text-danger", text: "Con 50.00 % o menos cabe.")

    fill_in "invoice_batch_percent", with: "40"
    click_button "Guardar cambios"
    expect(page).to have_content("Factura actualizada")
    expect(invoice.batch_invoices.sole).to have_attributes(percent: 40, gross_weight: 560)
  end

  def dom_id(record, prefix) = ActionView::RecordIdentifier.dom_id(record, prefix)
end
