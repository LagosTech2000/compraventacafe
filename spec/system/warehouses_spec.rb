require "rails_helper"

# Warehouses on screen (client, 2026-10-26): «Trasladar café» warns while
# typing when it takes more than the warehouse has, a shipment warns with
# the stock of the warehouse chosen, and the warehouse tabs of the stock
# change it without reloading the page.
RSpec.describe "Warehouses", type: :system do
  let(:user) { create(:user, :admin) }
  let(:main) { Warehouse.main! }
  let!(:other) { create(:warehouse, name: "Bodega 2") }

  def mark_page = page.execute_script("document.body.dataset.pageMarker = 'still here'")
  def page_reloaded? = page.evaluate_script("document.body.dataset.pageMarker") != "still here"

  before do
    create(:purchase, gross_weight: 2_000, warehouse: main) # 973.63 lb net
    sign_in_as(user)
  end

  it "warns while typing a transfer over what the warehouse has, and saves it" do
    visit new_sales_warehouse_transfer_path
    select "Bodega 1", from: "warehouse_transfer_from_warehouse_id"
    select "Bodega 2", from: "warehouse_transfer_to_warehouse_id"
    expect(page).to have_css("[data-transfer-preview-target='available']", text: "973.63 lb")

    fill_in "warehouse_transfer_net_weight", with: "1000"
    expect(page).to have_css("[data-transfer-preview-target='overStock']", visible: true)
    fill_in "warehouse_transfer_net_weight", with: "500"
    expect(page).to have_no_css("[data-transfer-preview-target='overStock']", visible: true)

    click_button "Trasladar"
    expect(page).to have_text("Traslado 0001")
    expect(WarehouseTransfer.sole).to have_attributes(from_warehouse: main, to_warehouse: other, net_weight: 500)
  end

  it "warns on a shipment with the stock of the warehouse chosen" do
    visit new_sales_shipment_path
    fill_in "shipment_origin_gross_weight", with: "1000"
    fill_in "shipment_origin_sacks", with: "6" # 487.06 lb net
    expect(page).to have_no_css("[data-weighing-calculator-target='stockNotice']", visible: true)

    select "Bodega 2", from: "shipment_warehouse_id"
    expect(page).to have_css("[data-weighing-calculator-target='stockNotice']", visible: true)
  end

  it "changes the stock's warehouse without reloading the page" do
    visit sales_stock_path
    mark_page
    expect(page).to have_css("[data-coffee-state='wet_parchment']", text: "973.63 lb")

    within("#stock-page nav") { click_link "Bodega 2" }
    expect(page).to have_css("[data-coffee-state='wet_parchment']", text: "0.00 lb")
    expect(page).to have_current_path(sales_stock_path(warehouse_id: other.id))
    expect(page_reloaded?).to be(false)
  end
end
