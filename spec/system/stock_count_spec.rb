require "rails_helper"

# «Contar bodega» (Fernando, 2026-11-18): the preview shows what the system
# says and the adjustment as the count is typed, and warns who is not an
# administrator when it passes their share.
RSpec.describe "Counting a warehouse", type: :system do
  it "previews the adjustment and saves the count" do
    create(:purchase, gross_weight: 1_000, purchased_at: 1.day.ago)
    seller = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "stock", can_read: true, can_create: true) }
    sign_in_as(seller)
    visit sales_stock_path
    click_link "Contar bodega"

    within("dialog[open]") do
      expect(page).to have_css("[data-count-preview-target=system]", text: "1,000.00 lb brutas")
      fill_in "Libras brutas contadas", with: "900"
      expect(page).to have_css("[data-count-preview-target=difference].text-danger", text: "−100.00 lb brutas")
      expect(page).to have_css("[data-count-preview-target=overShare]", visible: true)

      fill_in "Libras brutas contadas", with: "990"
      expect(page).to have_css("[data-count-preview-target=difference]", text: "−10.00 lb brutas")
      expect(page).to have_no_css("[data-count-preview-target=overShare]", visible: true)
      select "Secado u oreo", from: "Motivo de la diferencia"
      click_button "Guardar conteo"
    end

    expect(page).to have_css(".toast", text: "Conteo 0001 registrado")
    expect(StockCount.sole.gross_weight).to eq(-10)
  end
end
