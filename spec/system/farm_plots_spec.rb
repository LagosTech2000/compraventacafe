require "rails_helper"

# Plots of a farm with their varieties (Fernando, 2026-11-15): written in the
# farm's form (farm_plots_form_controller.js) and chosen in «Nueva compra»
# after the farm (farm_plots_controller.js).
RSpec.describe "Farm plots", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "adds and removes plots with their varieties in the farm's form" do
    parainema = CoffeeVariety.create!(name: "Parainema")
    farm = create(:farm, producer: create(:producer), name: "Las Labranzas")
    visit edit_farms_farm_path(farm)
    expect(page).to have_text("Sin parcelas.")

    click_button "Agregar parcela"
    click_button "Agregar parcela"
    rows = all("[data-farm-plots-form-target=row]")
    within(rows.first) do
      fill_in with: "Lote 1", match: :first, placeholder: "Ej.: Lote 1"
      check "Parainema"
    end
    within(rows.last) { click_button "Quitar" }
    expect(page).to have_css("[data-farm-plots-form-target=row]", count: 1)
    check "Parainema", match: :first
    click_button "Guardar cambios"

    expect(page).to have_css("[data-farm-plots] tbody tr", text: "Lote 1")
    expect(farm.reload.plots.sole).to have_attributes(name: "Lote 1", variety_ids: [ parainema.id ])
    expect(farm.variety_ids).to eq([ parainema.id ])
  end

  it "offers the plots of the farm chosen in «Nueva compra» and saves it" do
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    farm = create(:farm, producer:, name: "Las Labranzas")
    plot = farm.plots.create!(name: "Lote 2")
    create(:farm, producer:, name: "El Cerro")
    visit new_trading_purchase_path
    pick_record "producer_search", producer.picker_label

    expect(page).to have_no_select("purchase_farm_plot_id")
    select "Las Labranzas", from: "purchase_farm_id"
    expect(page).to have_select("purchase_farm_plot_id", options: [ "Sin parcela", "Lote 2" ])
    select "Lote 2", from: "purchase_farm_plot_id"
    select "El Cerro", from: "purchase_farm_id"
    expect(page).to have_no_select("purchase_farm_plot_id")
    select "Las Labranzas", from: "purchase_farm_id"
    select "Lote 2", from: "purchase_farm_plot_id"

    fill_in "purchase_gross_weight", with: "330"
    fill_in "purchase_price_per_pound", with: "58"
    select "Sin carrero", from: "purchase_hauler_choice"
    click_button "Crear Compra"
    expect(page).to have_text("Compra registrada", wait: 5)
    expect(Purchase.last).to have_attributes(farm:, farm_plot: plot)
  end
end
