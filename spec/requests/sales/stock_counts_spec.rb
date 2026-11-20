require "rails_helper"

# Inventario → «Contar bodega», Conteos and «Cuadre del día» (Fernando,
# 2026-11-18).
RSpec.describe "Stock counts and the day's reconciliation" do
  let(:admin) { create(:user, :admin) }
  let(:seller) do
    create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "stock", can_read: true, can_create: true, can_update: true, can_destroy: true) }
  end
  let(:warehouse) { Warehouse.main! }

  def page = Nokogiri::HTML(response.body)

  before { create(:purchase, gross_weight: 1_000, purchased_at: 2.days.ago) }

  it "counts a warehouse from Inventario and shows its adjustment, loss and lots" do
    sign_in seller
    get sales_stock_path
    expect(page.css("a").map(&:text)).to include("Contar bodega", "Conteos", "Cuadre del día")

    get new_sales_stock_count_path(warehouse_id: warehouse.id)
    expect(response).to have_http_status(:ok)
    expect(page.at_css("[data-controller~='count-preview']")["data-count-preview-limit-value"]).to eq("2.0")

    post sales_stock_counts_path, params: { stock_count: { warehouse_id: warehouse.id, coffee_state: "wet_parchment", counted_at: 1.hour.ago,
                                                           counted_gross: "990", counted_sacks: "6", reason: "drying" } }
    count = StockCount.last
    expect(count).to have_attributes(gross_weight: -10, counted_sacks: 6, created_by: seller)
    get sales_stock_count_path(count)
    expect(page.at_css("[data-count-adjustment]").text).to include("−10.00 lb brutas")
    expect(page.at_css("[data-count-loss]").text).to include("la merma vale L")
    expect(response.body).to include("Lotes de donde salió la diferencia")

    get sales_stock_counts_path
    expect(page.css("#stock_count_#{count.id}")).to be_present
  end

  it "refuses a large adjustment to who is not an administrator, and lets only an administrator void" do
    sign_in seller
    post sales_stock_counts_path, params: { stock_count: { warehouse_id: warehouse.id, coffee_state: "wet_parchment", counted_at: 1.hour.ago,
                                                           counted_gross: "500", reason: "loss" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("solo un administrador")

    count = create(:stock_count, counted_gross: 500, reason: "loss", created_by: admin)
    patch void_sales_stock_count_path(count), params: { stock_count: { void_reason: "Mal pesado" } }
    expect(count.reload).not_to be_voided

    sign_in admin
    get sales_stock_count_path(count)
    expect(response.body).to include("Anular conteo")
    patch void_sales_stock_count_path(count), params: { stock_count: { void_reason: "Mal pesado" } }
    expect(count.reload).to have_attributes(voided_by: admin, void_reason: "Mal pesado")
  end

  it "shows the kardex move of a count" do
    create(:stock_count, counted_gross: 900, reason: "drying", counted_at: 1.hour.ago)
    sign_in admin
    get sales_stock_path(warehouse_id: warehouse.id)
    expect(response.body).to include("Ajuste por conteo")
  end

  it "reconciles a day by coffee state and by shipment" do
    count = create(:stock_count, counted_gross: 900, reason: "drying", counted_at: 1.hour.ago)
    shipment = create(:shipment, :received, origin_gross_weight: 500, origin_sacks: 3, departed_at: 30.minutes.ago)
    sign_in admin

    get sales_stock_reconciliation_path
    expect(response).to have_http_status(:ok)
    row = page.at_css("#reconciliation_wet_parchment")
    expect(row.at_css("[data-move=adjustment]").text).to include("−100.00")
    expect(row.at_css("[data-move=shipment]").text).to include("−500.00")
    expect(row.at_css("[data-counts]").text).to include("Conteo #{count.display_number}")
    expect(page.at_css("#reconciliation_shipment_#{shipment.id}")).to be_present

    get sales_stock_reconciliation_path(date: 2.days.ago.to_date.iso8601, warehouse_id: warehouse.id)
    expect(page.at_css("#reconciliation_wet_parchment [data-move=purchase]").text).to include("+1,000.00")
    expect(page.at_css("#reconciliation_wet_parchment [data-counts]").text).to include("Sin conteo")
  end

  # «Lotes» from Inventario too (Fernando, 2026-11-19), for who sees Salidas.
  it "links the lots from Inventario only to who sees them" do
    sign_in seller
    get sales_stock_path
    expect(page.css("a").map(&:text)).not_to include("Lotes")

    sign_in admin
    get sales_stock_path
    expect(page.css("a").find { it.text == "Lotes" }["href"]).to eq(sales_coffee_batches_path)
  end

  it "keeps both screens to who sees Inventario" do
    other = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "shipments", can_read: true) }
    sign_in other
    get sales_stock_reconciliation_path
    expect(response).to redirect_to(root_path)
    get sales_stock_counts_path
    expect(response).to redirect_to(root_path)
  end
end
