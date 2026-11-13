require "rails_helper"

# What a shipment cost (Fernando, 2026-11-12), on screen: a cost shows its
# amount as it is typed. (Its lots, from 2026-11-13: coffee_batches_spec.)
RSpec.describe "Shipment cost", type: :system do
  let(:admin) { create(:user, :admin) }

  it "registers a cost per quintal, showing its amount as it is typed" do
    shipment = create(:shipment)
    sign_in_as(admin)

    visit sales_shipment_path(shipment)
    expect(page).to have_css("[data-cost-missing]")

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
