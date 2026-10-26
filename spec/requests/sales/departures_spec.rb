require "rails_helper"

# «Nueva salida» (client, 2026-10-26): first the kind — a sale, processing
# or a transfer — and each one opens its own form.
RSpec.describe "New departure" do
  def page = Nokogiri::HTML(response.body)

  it "offers the three kinds, each to its form, from the module's main button" do
    sign_in create(:user, :admin)
    get sales_root_path
    expect(page.at_css(".subnav-action a")["href"]).to eq(new_sales_departure_path)

    get new_sales_departure_path
    links = page.css("[data-departure-kinds] a")
    expect(links.map { it.text.squish.split.first }).to eq(%w[Venta Procesamiento Traslado])
    expect(links.map { it["href"] }).to eq([ new_sales_shipment_path, new_sales_coffee_conversion_path, new_sales_warehouse_transfer_path ])
  end

  it "is only for who creates in Comercialización" do
    reader = create(:user).tap { create(:permission, user: it, module_key: "sales", can_read: true) }
    sign_in reader
    get sales_root_path
    expect(page.at_css(".subnav-action")).to be_nil
    get new_sales_departure_path
    expect(response).to redirect_to(root_path)
  end
end
