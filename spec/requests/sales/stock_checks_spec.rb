require "rails_helper"

# The «Netas y sacos, revisados» card in Inventario and in the detail of a
# coffee state, and the page that explains it, for administrators only.
RSpec.describe "Stock checks", type: :request do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)
  let(:clerk) do
    create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "stock", can_read: true) }
  end

  before do
    create(:purchase, coffee_state: "wet_parchment", gross_weight: 1_650, humidity_percent: 51, damage_percent: 2, damage_types: %w[borer])
    create(:shipment, coffee_state: "wet_parchment", origin_gross_weight: 500, origin_sacks: 4)
  end

  it "shows the card in Inventario and in the detail, with «¿Por qué?» only to administrators" do
    sign_in clerk
    get sales_stock_path
    expect(page.at_css("[data-net-check] [data-net-check-row=wet_parchment]").text).to include("1,150.00", "563.50")
    expect(page.at_css("[data-net-check]").text).not_to include("¿Por qué?")
    get sales_stock_state_path("wet_parchment")
    expect(page.at_css("[data-net-check-row=wet_parchment]")).to be_present
    get sales_stock_check_path("wet_parchment")
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")

    sign_in admin
    get sales_stock_path
    expect(page.at_css("[data-net-check]").text).to include("¿Por qué?")
  end

  it "explains the difference part by part to an administrator" do
    shipment = Shipment.sole
    sign_in admin
    get sales_stock_check_path("wet_parchment")
    expect(response).to have_http_status(:ok)
    expect(page.css("[data-check-part]").map { it["data-check-part"] }).to eq(%w[purchases shipments])
    expect(page.at_css("[data-check-shipment='#{shipment.display_number}']").text).to include("Su báscula local")
    expect(page.text).to include("Tara: 10.00 lb", "Daño:", "Los sacos")
  end
end
