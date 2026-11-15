require "rails_helper"

# Lots from «Nueva salida» (Fernando, 2026-11-13): only the free lots of
# the coffee state and warehouse chosen show; «Nuevo lote» makes one in a
# window, with its invoices, and it comes back marked.
RSpec.describe "Lots in the shipment form", type: :system do
  let(:admin) { create(:user, :admin) }

  it "shows the lots that fit, and makes a new one with its invoices from the window" do
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    purchase = create(:purchase, producer:, gross_weight: 500)
    invoice = InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
    create(:coffee_batch, coffee_state: "cherry")
    sign_in_as(admin)
    visit new_sales_shipment_path

    expect(page).to have_css("[data-batch-picker-target=item]", count: 0, visible: true)
    select "Uva", from: "shipment_coffee_state"
    expect(page).to have_css("[data-batch-picker-target=item]", count: 1, visible: true)
    select "Pergamino húmedo", from: "shipment_coffee_state"
    expect(page).to have_css("[data-batch-picker-target=empty]", visible: true)

    click_link "Nuevo lote"
    within("dialog[open]") do
      fill_in "coffee_batch_gross_limit", with: "800"
      click_button "Crear lote y elegir facturas"
      expect(page).to have_css("[data-batch-invoice-choices]")
      find("input[name='shares[#{invoice.id}][chosen]']").check
      net = ->(percent) { ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", (invoice.net_weight * percent / 100).round(2))) }
      expect(page).to have_css("[data-takes-gross]", text: "500.00 lb brutas")
      expect(page).to have_css("[data-takes-net]", text: "#{net.(100)} lb netas")
      # Beside the percent, what it comes to (Fernando, 2026-11-13).
      fill_in "shares[#{invoice.id}][percent]", with: "50"
      expect(page).to have_css("[data-takes-gross]", text: "250.00 lb brutas")
      expect(page).to have_css("[data-takes-net]", text: "#{net.(50)} lb netas")
      # The input and its pounds end where their column's header ends.
      edges = page.evaluate_script(<<~JS)
        (() => { const th = [...document.querySelectorAll("[data-batch-invoice-choices] th")].find(el => el.textContent.includes("Parte"));
          const out = document.querySelector("[data-takes]"), input = out.previousElementSibling, pad = parseFloat(getComputedStyle(th).paddingRight);
          return { header: Math.round(th.getBoundingClientRect().right - pad), pounds: Math.round(out.getBoundingClientRect().right),
                   beside: input.getBoundingClientRect().right <= out.getBoundingClientRect().left } })()
      JS
      expect(edges["pounds"]).to be_within(2).of(edges["header"])
      expect(edges["beside"]).to be(true)
      click_button "Agregar al lote"
    end
    expect(page).to have_no_css("dialog[open]")
    item = find("[data-batch-picker-target=item]", text: "Lote 0002")
    expect(item.find("input[type=checkbox]")).to be_checked
    expect(CoffeeBatch.find_by!(number: 2).batch_invoices.sole).to have_attributes(invoice:, percent: 50)
  end

  it "marks many invoices at once: all, a range with Shift, or filling the lot (Fernando, 2026-11-15)" do
    producer = create(:producer)
    invoices = Array.new(3) do
      purchase = create(:purchase, producer:, gross_weight: 500)
      InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
    end
    batch = create(:coffee_batch, gross_limit: 1_200)
    sign_in_as(admin)
    visit new_sales_coffee_batch_invoice_path(batch)
    boxes = -> { all("[data-batch-shares-target=row] input[type=checkbox]") }

    find("#batch_invoices_all").check
    expect(boxes.call.map(&:checked?)).to eq([ true, true, true ])
    expect(page).to have_text("3 marcadas: 1,500.00 lb brutas, más de las 1,200.00 que caben.")
    expect(page).to have_button("Agregar al lote", disabled: true)
    find("#batch_invoices_all").uncheck
    expect(boxes.call.map(&:checked?)).to eq([ false, false, false ])

    boxes.call.first.click
    boxes.call.last.click(:shift)
    expect(boxes.call.map(&:checked?)).to eq([ true, true, true ])
    find("#batch_invoices_all").uncheck

    click_button "Llenar el lote"
    expect(page).to have_text("3 marcadas: 1,200.00 lb brutas de 1,200.00 que caben.")
    expect(all("[data-batch-shares-target=row] input[name$='[percent]']").map(&:value)).to eq(%w[100 100 40])
    click_button "Agregar al lote"
    expect(page).to have_text("3 facturas en el lote.")
    expect(batch.batch_invoices.sum(:percent)).to eq(240)
    expect(batch.reload.gross_weight).to eq(1_200)
    expect(invoices.map { it.batch_invoices.sole.percent }.sort).to eq([ 40, 100, 100 ])
  end
end
