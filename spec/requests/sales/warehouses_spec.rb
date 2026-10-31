require "rails_helper"

# Warehouses, transfers and the stock lot by lot (client, 2026-10-26).
RSpec.describe "Sales warehouses and lots" do
  let(:admin) { create(:user, :admin) }
  let(:main) { Warehouse.main! }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "creates, renames and lists warehouses with their coffee, and deletes only unused ones" do
    main
    get new_sales_warehouse_path
    expect(page.at_css("#warehouse_name")["value"]).to eq("Bodega 2")

    post sales_warehouses_path, params: { warehouse: { name: " Bodega  del  río " } }
    river = Warehouse.find_by!(name: "Bodega del río")
    expect(AuditEvent.where(auditable: river, action: "create")).to exist

    create(:purchase, gross_weight: 2_000) # 973.63 net into the default one
    get sales_warehouses_path
    expect(page.at_css("#warehouse_#{main.id}").text.squish).to include("Bodega 1", "Por defecto", "973.63")
    get sales_warehouses_path(sort: "net_wet_parchment", dir: "desc")
    expect(page.css("tbody tr").first["id"]).to eq("warehouse_#{main.id}")

    patch sales_warehouse_path(river), params: { warehouse: { name: "Bodega Norte", main: "1" } }
    expect([ river.reload.main?, main.reload.main? ]).to eq([ true, false ])

    delete sales_warehouse_path(river)
    expect(Warehouse.exists?(river.id)).to be(true) # the default one is not deleted
    patch sales_warehouse_path(main), params: { warehouse: { main: "1" } }
    delete sales_warehouse_path(river)
    expect(Warehouse.exists?(river.id)).to be(false)
  end

  it "does not deactivate the default warehouse nor one with coffee" do
    other = create(:warehouse, name: "Bodega 2")
    create(:purchase, gross_weight: 2_000, warehouse: other)

    patch sales_warehouse_path(main), params: { warehouse: { active: "0" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("La bodega por defecto no se puede desactivar")
    patch sales_warehouse_path(other), params: { warehouse: { active: "0" } }
    expect(response.body).to include("La bodega todavía tiene café")
    expect(other.reload).to be_active
  end

  it "registers a purchase and a shipment in the warehouse chosen" do
    main
    other = create(:warehouse, name: "Bodega 2")
    get new_trading_purchase_path
    expect(page.at_css("#purchase_warehouse_id option[selected]").text).to eq("Bodega 1")

    purchase = create(:purchase, gross_weight: 2_000, warehouse: other)
    get trading_purchase_path(purchase)
    expect(response.body).to include("Bodega 2")
    shipment = create(:shipment, warehouse: other)
    get sales_shipment_path(shipment)
    expect(page.at_css("#shipment-details").parent.text.squish).to include("BodegaBodega 2")
  end

  it "transfers coffee between warehouses in gross pounds, shows its lots and voids it" do
    other = create(:warehouse, name: "Bodega 2")
    purchase = create(:purchase, gross_weight: 2_000, purchased_at: 1.day.ago)

    get new_sales_warehouse_transfer_path
    expect(page.at_css("label[for='warehouse_transfer_gross_weight']").text).to eq("Libras brutas")
    expect(page.at_css("#warehouse_transfer_net_weight")).to be_nil

    # Written in gross pounds (client, 2026-10-30); the net ones come from
    # the warehouse's net/gross proportion of that state.
    post sales_warehouse_transfers_path, params: { warehouse_transfer: { from_warehouse_id: main.id, to_warehouse_id: other.id, coffee_state: "wet_parchment",
                                                                         gross_weight: "1000", net_weight: "1", transferred_at: Time.current.strftime("%Y-%m-%dT%H:%M") } }
    transfer = WarehouseTransfer.sole
    net = (1_000 * (purchase.net_weight / 2_000).round(6)).round(2)
    expect(transfer).to have_attributes(number: 1, gross_weight: 1_000, net_weight: net)
    expect(AuditEvent.where(auditable: transfer, action: "create")).to exist
    shown = ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", net))

    get sales_warehouse_transfer_path(transfer)
    expect(page.at_css("#transfer-lots").parent.text.squish).to include("Compra de #{purchase.producer.full_name}", shown)
    get sales_warehouse_transfers_path(warehouse_id: other.id)
    expect(page.at_css("#warehouse_transfer_#{transfer.id}").text.squish).to include("Bodega 1", "Bodega 2", shown)
    get sales_stock_path(warehouse_id: other.id)
    expect(page.at_css("[data-coffee-state='wet_parchment']").text.squish).to include("#{shown} lb")
    expect(response.body).to include("Llegó por traslado")

    post sales_warehouse_transfers_path, params: { warehouse_transfer: { from_warehouse_id: main.id, to_warehouse_id: main.id, coffee_state: "wet_parchment",
                                                                         gross_weight: "1", transferred_at: Time.current.strftime("%Y-%m-%dT%H:%M") } }
    expect(response.body).to include("debe ser otra bodega")

    patch void_sales_warehouse_transfer_path(transfer)
    expect(transfer.reload).to be_voided
    expect(CoffeeStock.new(warehouse: other).row("wet_parchment").stock).to eq(0)
  end

  it "shows a coffee state's figures, value and lots, the oldest one marked to go out first" do
    older = create(:purchase, gross_weight: 2_000, purchased_at: 3.days.ago, hauler: create(:hauler, price_per_pound: 0.5))
    newer = create(:purchase, gross_weight: 1_000, purchased_at: 1.day.ago)

    get sales_stock_path
    expect(page.at_css("[data-coffee-state='wet_parchment']")["href"]).to eq(sales_stock_state_path("wet_parchment"))

    get sales_stock_state_path("wet_parchment")
    expect(response).to have_http_status(:ok)
    value = page.at_css("[data-stock-value]").text.squish
    expect(value).to include("L #{ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", older.total + newer.total))}",
                             "L #{format("%.2f", older.hauler_commission)}")
    rows = page.css("tbody tr")
    expect(rows.map { it["id"] }).to eq([ "lot_purchase_#{newer.id}", "lot_purchase_#{older.id}" ])
    expect(rows.last.text).to include("Sale primero", "3 días")

    get sales_stock_state_path("total", warehouse_id: main.id)
    expect(response).to have_http_status(:ok)
  end

  it "warns about cherry waiting too long, on the stock and the pending work" do
    create(:purchase, coffee_state: "cherry", gross_weight: 1_000, purchased_at: 13.hours.ago)
    late = create(:purchase, coffee_state: "cherry", gross_weight: 1_000, purchased_at: 25.hours.ago)
    create(:purchase, coffee_state: "cherry", gross_weight: 1_000, purchased_at: 2.hours.ago)

    alert = CherryAlert.new
    expect(alert.items.map(&:level)).to eq(%w[critical warning])
    expect(alert.items.first.lot.source).to eq(late)

    get sales_root_path
    expect(page.at_css("section[data-cherry-alert='critical']").text.squish).to include("2 lotes")
    get sales_stock_state_path("cherry")
    expect(page.css("[data-cherry-alert='critical']").size).to be >= 1
    get pending_work_path
    expect(page.at_css("#pending-cherry_waiting").css("li").size).to eq(2)

    SiteSetting.create!(business_name: "Rey David", cherry_warning_hours: 30, cherry_critical_hours: 48)
    expect(CherryAlert.new.items).to be_empty
  end
end
