require "rails_helper"

# The live preview of the purchase calculation (purchase_calculator_controller.js).
RSpec.describe "Purchase form preview", type: :system do
  let(:user) { create(:user, :admin) }

  before do
    sign_in_as(user)
    visit new_trading_purchase_path
  end

  def figure(name) = find("[data-purchase-calculator-target='#{name}']").text

  def figures
    %w[sacks tare damageWeight damageAmount netWeight quintals total].to_h { |name| [ name, figure(name) ] }
  end

  it "takes the damage off in pounds and lempiras" do
    fill_in "purchase_gross_weight", with: "1000"
    fill_in "purchase_damage_percent", with: "2.5"
    fill_in "purchase_price_per_pound", with: "60"

    # (1000 − 7) × 0.49 = 486.57; 2.5 % of damage = 12.16 lb = L 729.60
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "474.41")
    expect(figures).to include("tare" => "7.00", "damageWeight" => "12.16", "damageAmount" => "L 729.60", "total" => "L 28,464.60")
  end

  it "keeps calculating when the damage is cleared, as 0 %" do
    fill_in "purchase_gross_weight", with: "1000"
    fill_in "purchase_price_per_pound", with: "60"
    fill_in "purchase_damage_percent", with: "2.5"
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "474.41")

    fill_in "purchase_damage_percent", with: ""
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "486.57")
    expect(figures).to include("damageWeight" => "0.00", "damageAmount" => "L 0.00", "quintals" => "3.89", "total" => "L 29,194.20")
  end

  it "keeps sacks and tare while the humidity is missing" do
    fill_in "purchase_gross_weight", with: "1000"
    fill_in "purchase_humidity_percent", with: ""

    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "—")
    expect(figures).to include("sacks" => "6.06", "tare" => "7.00", "total" => "—")
  end

  it "uses the yield in cherry and the damage again back in parchment" do
    fill_in "purchase_gross_weight", with: "1000"
    fill_in "purchase_price_per_pound", with: "10"
    select "Uva", from: "purchase_coffee_state"
    # (1000 − 7) × 0.186 = 184.70
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "184.70")
    expect(page).to have_no_field("purchase_damage_percent")

    select "Pergamino húmedo", from: "purchase_coffee_state"
    expect(page).to have_field("purchase_damage_percent", with: "0")
    expect(page).to have_css("[data-purchase-calculator-target='netWeight']", text: "486.57")
  end

  it "keeps the calculation and the buttons on the right on wide screens, and below on phones" do
    box = ->(selector) { page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return [r.left, r.top] })()") }

    calculation_left, = box.call("aside")
    gross_left, = box.call("#purchase_gross_weight")
    expect(calculation_left).to be > gross_left + 400

    page.driver.resize(390, 900)
    expect(page).to have_css("aside")
    _, calculation_top = box.call("aside")
    _, observations_top = box.call("#purchase_observations")
    expect(calculation_top).to be > observations_top
  end
end
