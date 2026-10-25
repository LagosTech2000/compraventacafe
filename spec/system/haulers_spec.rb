require "rails_helper"

# Carreros on screen (Fernando, 2026-10-16): the commission preview in the
# purchase form (hauler_commission_controller.js) and the carrero's terms in
# the person form (person_roles_controller.js).
RSpec.describe "Carreros", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "previews the carrero's commission as the purchase is typed, and hides it without one" do
    create(:hauler, person: create(:person, first_names: "Rubén", last_names: "Ordóñez"), price_per_pound: "0.3")
    visit new_trading_purchase_path
    expect(page).to have_no_text("Comisión del carrero")

    select "Uva", from: "purchase_coffee_state"
    fill_in "purchase_gross_weight", with: "1661"
    fill_in "purchase_yield_factor", with: "1"
    select "Rubén Ordóñez", from: "purchase_hauler_id"

    within("[data-hauler-commission-target='box']") do
      expect(page).to have_text("L 0.30 por libra neta")
      expect(page).to have_css("[data-hauler-commission-target='amount']", text: "L 495.00")
    end

    fill_in "purchase_gross_weight", with: "836" # 830 lb net
    expect(page).to have_css("[data-hauler-commission-target='amount']", text: "L 249.00")

    select "Sin carrero", from: "purchase_hauler_id"
    expect(page).to have_no_text("Comisión del carrero")
  end

  it "asks a new carrero's price per pound only while «Carrero» is checked" do
    visit new_administration_person_path
    fill_in "person_first_names", with: "Rubén"
    fill_in "person_last_names", with: "Ordóñez"
    expect(page).to have_no_field("person_hauler_price_per_pound")

    check "person_hauler_role"
    expect(page).to have_field("person_hauler_price_per_pound")
    find("main form [type=submit]").click
    expect(find("#person_hauler_price_per_pound").evaluate_script("this.validationMessage")).to eq("Precio por libra neta (L) no puede estar en blanco")

    fill_in "person_hauler_price_per_pound", with: "0.3"
    find("main form [type=submit]").click
    expect(page).to have_text("Persona creada.")
    expect(Person.last.hauler).to have_attributes(price_per_pound: BigDecimal("0.3"))
  end
end
