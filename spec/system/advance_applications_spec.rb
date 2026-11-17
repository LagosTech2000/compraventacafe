require "rails_helper"

# Applying an advance to sales by a % of it (Fernando, 2026-11-16;
# advance_shares_controller.js): each marked sale shows the money its
# percent comes to and what the sale still owes; passing what is free of
# the advance or what a sale owes keeps «Aplicar» off.
RSpec.describe "Advance applications", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:buyer) { create(:buyer, name: "Exportadora Norte") }

  def sale_of(total)
    shipment = create(:shipment, :received, buyer:)
    SaleIssuer.new(buyer:, user: admin, shipment_ids: [ shipment.id ], payment_status: "pending",
                   sale: { price_unit: "pound", unit_price: (total / shipment.destination_net_weight).round(6).to_s, quintal_pounds: "120" }).call.sale
  end

  it "shows the money of each percent and applies it" do
    advance = create(:buyer_advance, buyer:, amount: 10_000)
    sale = sale_of(6_000)
    sign_in_as(admin)
    visit new_sales_advance_application_path(advance_id: advance.id)

    row = find("tr[id='application_sale_#{sale.id}']")
    row.find("input[type=checkbox]").check
    row.fill_in(with: "70", currently_with: "100")
    expect(row).to have_text("Pasa de lo que falta")
    expect(page).to have_button("Aplicar", disabled: true)

    row.find("input[name$='[percent]']").fill_in(with: "40")
    expect(row).to have_text("L 4,000.00")
    left = ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", sale.balance_due - 4_000))
    expect(row).to have_text("Le queda L #{left} por cobrar")
    expect(page).to have_text("Toma 40 % del anticipo: L 4,000.00.")
    click_button "Aplicar"
    expect(page).to have_text("Anticipo aplicado a 1 venta.")
    expect(advance.reload.applied_amount).to eq(4_000)
  end
end
