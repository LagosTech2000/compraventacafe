require "rails_helper"

# Converting coffee on screen: the preview of what leaves the stock and of
# what comes in (conversion_preview_controller.js), and the stock's cards
# that open the kardex of their state.
RSpec.describe "Coffee conversions screens", type: :system do
  let(:user) { create(:user, :admin) }

  before do
    create(:purchase, gross_weight: 2_000) # 973.63 lb net of wet parchment: 0.486815 a gross pound
    create(:processing_site, name: "Patio")
    sign_in_as(user)
  end

  it "previews what leaves the stock, warns past it, and enters what came out" do
    visit sales_coffee_conversions_path
    click_link "Procesar café"

    within("dialog[open]") do
      expect(page).to have_field("coffee_conversion_estimated_yield_percent", with: "37.95")
      expect(page).to have_no_field("coffee_conversion_input_humidity_percent")
      choose "Pergamino húmedo → Pergamino seco"
      expect(page).to have_field("coffee_conversion_estimated_yield_percent", with: "50")
      fill_in "coffee_conversion_input_humidity_percent", with: "51"
      select "Patio", from: "coffee_conversion_processing_site_id"
      expect(page).to have_css("[data-conversion-preview-target=available]", text: "2,000.00 lb")
      expect(page).to have_css("[data-conversion-preview-target=toState]", text: "Pergamino seco")
      fill_in "coffee_conversion_input_gross_weight", with: "1000"
      expect(page).to have_css("[data-conversion-preview-target=net]", text: "486.82 lb")
      expect(page).to have_css("[data-conversion-preview-target=quintals]", text: "3.89")
      expect(page).to have_css("[data-conversion-preview-target=estimatedOutput]", text: "500.00 lb")
      expect(page).to have_no_text("roporción")

      fill_in "coffee_conversion_input_gross_weight", with: "2500"
      expect(page).to have_css("[data-conversion-preview-target=overStock]", visible: true)
      fill_in "coffee_conversion_input_gross_weight", with: "1000"
      expect(page).to have_css("[data-conversion-preview-target=overStock]", visible: :hidden)
      click_button "Pesar y mandar a procesar"
    end
    expect(page).to have_no_css("dialog[open]")
    conversion = CoffeeConversion.sole

    visit sales_coffee_conversion_path(conversion)
    click_link "Registrar resultado"
    within("dialog[open]") do
      expect(page).to have_field("coffee_conversion_output_humidity_percent", with: "12")
      fill_in "coffee_conversion_output_gross_weight", with: "600"
      fill_in "coffee_conversion_output_sacks", with: "4"
      expect(page).to have_css("[data-conversion-preview-target=net]", text: "524.48 lb")
      expect(page).to have_css("[data-conversion-preview-target=quintals]", text: "4.20")
      expect(page).to have_css("[data-conversion-preview-target=realYield]", text: "60 %")
      expect(page).to have_css("[data-conversion-preview-target=estimateDifference]", text: "100.00 lb brutas más de lo estimado")
      fill_in "coffee_conversion_output_damage_percent", with: "2"
      expect(page).to have_css("[data-conversion-preview-target=net]", text: "513.99 lb")
      fill_in "coffee_conversion_output_damage_percent", with: ""
      click_button "Registrar resultado"
    end
    expect(page).to have_text("ya está en el inventario")
    expect(conversion.reload.output_net_weight).to eq(BigDecimal("524.48"))
  end

  it "opens a state's detail from its card on the summary, and its kardex from there" do
    visit sales_root_path
    find("[data-coffee-state=wet_parchment]").click
    expect(page).to have_current_path(sales_stock_state_path("wet_parchment"))
    click_link "Ver movimientos"
    expect(page).to have_select("coffee_state", selected: "Pergamino húmedo")

    visit sales_root_path
    find("[data-coffee-state=total]").click
    expect(page).to have_current_path(sales_stock_state_path("total"))
  end

  it "calculates a processing cost as it is typed and shows only the fields of the way it is charged" do
    conversion = create(:coffee_conversion, :finished, input_gross_weight: 1_000, weighed_at: 3.hours.ago) # 400 lb out
    visit new_sales_coffee_conversion_cost_path(conversion)

    expect(page).to have_no_field("processing_cost_unit_price")
    fill_in "processing_cost_amount", with: "300"
    expect(page).to have_css("[data-processing-cost-target=result]", text: "L 300.00")

    choose "Por quintal"
    expect(page).to have_no_field("processing_cost_amount")
    fill_in "processing_cost_unit_price", with: "20"
    expect(page).to have_css("[data-processing-cost-target=result]", text: "L 200.00") # 1,000 lb ÷ 100 × 20
    select "Quintal de 125 lb", from: "processing_cost_quintal_pounds"
    choose "Que salió"
    expect(page).to have_css("[data-processing-cost-target=base]", text: "400.00 lb")
    expect(page).to have_css("[data-processing-cost-target=result]", text: "L 64.00") # 400 ÷ 125 × 20

    choose "Por libra"
    expect(page).to have_no_select("processing_cost_quintal_pounds")
    expect(page).to have_css("[data-processing-cost-target=result]", text: "L 8,000.00")
  end
end
