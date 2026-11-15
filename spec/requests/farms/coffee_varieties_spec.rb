require "rails_helper"

# Fincas → Variedades (Fernando, 2026-11-15): a catalog with the farms'
# permissions; farms and plots choose them in the farm's form.
RSpec.describe "Coffee varieties and plots" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)

  it "adds, renames and deactivates a variety, for who edits farms" do
    sign_in admin
    post farms_coffee_varieties_path, params: { coffee_variety: { name: " Parainema " } }
    variety = CoffeeVariety.sole
    expect(variety.name).to eq("Parainema")

    patch farms_coffee_variety_path(variety), params: { coffee_variety: { name: "Parainema", active: "0" } }
    expect(variety.reload).not_to be_active
    get farms_coffee_varieties_path(status: "inactive")
    expect(response.body).to include("Parainema")

    reader = create(:user).tap { create(:permission, user: it, module_key: "farms", can_read: true) }
    sign_in reader
    post farms_coffee_varieties_path, params: { coffee_variety: { name: "Lempira" } }
    expect(CoffeeVariety.count).to eq(1)
  end

  it "saves a farm's varieties and plots from its form, and shows them" do
    sign_in admin
    lempira = CoffeeVariety.create!(name: "Lempira")
    ihcafe = CoffeeVariety.create!(name: "IHCAFE 90")
    farm = create(:farm, producer: create(:producer))

    get edit_farms_farm_path(farm)
    expect(response.body).to include("Agregar parcela", "IHCAFE 90")

    patch farms_farm_path(farm), params: { farm: { name: farm.name, variety_ids: [ "", lempira.id ],
                                                   plots_attributes: { "0" => { name: "Lote 1", area_value: "2", area_unit: "manzana", variety_ids: [ "", ihcafe.id ] } } } }
    expect(farm.reload.variety_names).to eq([ "Lempira" ])
    expect(farm.plots.sole).to have_attributes(name: "Lote 1", area_value: 2, variety_ids: [ ihcafe.id ])

    get farms_farm_path(farm)
    row = page.at_css("[data-farm-plots] tbody tr")
    expect(row.text.squish).to include("Lote 1", "IHCAFE 90")
    expect(page.at_css("[data-farm-plots]").text.squish).to include("Variedades: Lempira")
  end
end
