require "rails_helper"

# «¿Qué café lleva?» in «Nueva salida» (shipment_coffee_controller.js,
# Fernando, 2026-11-18): the invoices of the chosen state and warehouse,
# shortcuts, and what it carries against the local scale.
RSpec.describe "What coffee a shipment carries", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer) }

  def invoice_of(purchase)
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
  end

  before { sign_in_as(admin) }

  it "shows the invoices of its coffee, marks them with shortcuts and adds them up against the local scale" do
    create(:shipment, departed_at: 1.day.ago)
    old = invoice_of(create(:purchase, producer:, gross_weight: 600, purchased_at: 2.days.ago))
    today = invoice_of(create(:purchase, producer:, gross_weight: 400, purchased_at: Time.current.beginning_of_day))
    dry = invoice_of(create(:purchase, producer:, coffee_state: "dry_parchment", humidity_percent: 12, purchased_at: 1.hour.ago))
    visit new_sales_shipment_path

    within("[data-controller~='shipment-coffee']") do
      expect(page).to have_css("#coffee_invoice_#{old.id}").and have_css("#coffee_invoice_#{today.id}")
      expect(page).to have_no_css("#coffee_invoice_#{dry.id}")
      click_button "Compras de hoy"
      expect(find("#carry_invoice_#{today.id}")).to be_checked
      expect(find("#carry_invoice_#{old.id}")).not_to be_checked
      expect(page).to have_css("[data-shipment-coffee-target='total']", text: "Lleva 400.00 lb brutas")
      click_button "Desde la última salida"
      expect(find("#carry_invoice_#{today.id}")).to be_checked
      click_button "Todo"
      expect(page).to have_css("[data-shipment-coffee-target='total']", text: "Lleva 1,000.00 lb brutas")
    end

    fill_in "shipment_origin_gross_weight", with: "990"
    expect(page).to have_css("[data-shipment-coffee-target='total']", text: "−10.00 lb brutas (−1.00 %)")

    # A % per invoice (Fernando, 2026-11-20): half of the old one.
    fill_in "carry_percent_invoice_#{old.id}", with: "50"
    expect(page).to have_css("[data-shipment-coffee-target='total']", text: "Lleva 700.00 lb brutas")
    expect(page).to have_field("carry_percent_invoice_#{dry.id}", disabled: true, visible: :all)

    select "Pergamino seco", from: "shipment_coffee_state"
    within("[data-controller~='shipment-coffee']") do
      expect(page).to have_css("#coffee_invoice_#{dry.id}")
      expect(page).to have_no_css("#coffee_invoice_#{old.id}")
      expect(page).to have_css("[data-shipment-coffee-target='total']", text: "Todavía no lleva café marcado.")
    end
  end
end
