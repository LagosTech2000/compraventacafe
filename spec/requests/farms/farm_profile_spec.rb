require "rails_helper"

# A farm's land (FarmArea) and what it produced and cost (FarmProfile),
# Fernando 2026-10-14.
RSpec.describe "Farm land and figures" do
  let(:admin) { create(:user, :admin) }
  let(:today) { Time.zone.today }

  before { sign_in admin }

  def figures = Nokogiri::HTML(response.body).css("[data-farm-figure]").to_h { |figure| [ figure["data-farm-figure"], figure.text.squish ] }

  it "saves the land in the unit written and shows it in every unit" do
    post farms_farms_path, params: { farm: { name: "El Roble", area_value: "10", area_unit: "manzana" } }
    farm = Farm.last
    expect(farm).to have_attributes(area_value: 10, area_unit: "manzana")
    expect(farm.area.hectares).to eq(BigDecimal("6.98896"))
    expect(farm.area.square_meters).to eq(BigDecimal("69889.6"))

    get farms_farms_path
    expect(response.body).to include("10 mz · 6.99 ha · 69,890 m²")

    patch farms_farm_path(farm), params: { farm: { area_value: "", area_unit: "hectare" } }
    expect(farm.reload).to have_attributes(area_value: nil, area_unit: nil)
  end

  it "refuses land without a unit, zero or negative" do
    farm = create(:farm)
    patch farms_farm_path(farm), params: { farm: { area_value: "5", area_unit: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    patch farms_farm_path(farm), params: { farm: { area_value: "0", area_unit: "hectare" } }
    expect(response).to have_http_status(:unprocessable_content)
    patch farms_farm_path(farm), params: { farm: { area_value: "5", area_unit: "acre" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(farm.reload.area_value).to be_nil
  end

  it "shows the coffee bought from the farm, what was picked, the yield per land and what it generated against its cost" do
    producer = create(:producer)
    farm = create(:farm, producer:, name: "El Cerro", area_value: 2, area_unit: "manzana")
    2.times { create(:purchase, producer:, farm:, gross_weight: 146) }
    create(:purchase, producer:, farm:, voided_at: Time.current, voided_by: admin)
    harvest = create(:payroll, farm:, kind: "harvest", can_price: 25, starts_on: today - 3)
    pickers = create_list(:payroll_member, 2, payroll: harvest)
    HarvestEntry.create!(member: pickers.first, worked_on: today, cans: 10)
    HarvestEntry.create!(member: pickers.second, worked_on: today - 1, cans: 6.5)
    create(:payroll_expense, payroll: harvest, amount: 1_000, spent_on: today)

    get farms_farm_path(farm)
    # Two purchases of 146 lb: 71.05 lb net each, L 4,120.90 each.
    expect(figures).to include(
      "quintals" => "QQ vendidos 1.14 1.14 QQ esta temporada",
      "sales_total" => "Valor del café L 8,241.80",
      "purchases_count" => "Compras 2",
      "average_price" => "Precio prom. por libra L 58.00",
      "cans" => "Latas cortadas 16.5",
      "cans_paid" => "Pagado por latas L 0.00",
      "harvest_days" => "Días de corte 2",
      "pickers" => "Cortadores 2",
      "area" => "Extensión 2 mz 1.4 ha · 13,978 m²",
      "quintals_per_manzana" => "QQ por manzana 0.57",
      "quintals_per_hectare" => "QQ por hectárea 0.81",
      "sales_per_manzana" => "Valor del café por manzana L 4,120.90",
      "cans_per_manzana" => "Latas por manzana 8.25",
      "generated" => "Generado L 8,241.80 El valor del café comprado de la finca.",
      "cost" => "Costo L 1,000.00 Planillas pagadas más gastos.",
      "balance" => "Diferencia L 7,241.80",
      "cost_per_quintal" => "Costo por QQ L 879.66"
    )
    expect(response.body).to include("El Cerro · ", "2 mz · 1.4 ha · 13,978 m²")
  end

  it "asks for the land to show the yield, and hides the coffee from who cannot see Compra de café" do
    farm = create(:farm)
    user = create(:user).tap { |u| create(:permission, user: u, module_key: "farms", can_read: true) }
    sign_in user
    get farms_farm_path(farm)
    expect(response.body).to include("Escribe la extensión de la finca")
    expect(figures.keys).not_to include("quintals", "sales_total", "balance")
    page = Nokogiri::HTML(response.body)
    expect(page.css("#farm-sales, #farm-balance")).to be_empty
    expect(response.body).not_to include("Agregar la extensión")
  end
end
