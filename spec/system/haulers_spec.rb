require "rails_helper"

# Carreros on screen (Fernando, 2026-10-16): the commission preview in the
# purchase form (hauler_commission_controller.js) and the carrero's terms in
# the person form (person_roles_controller.js).
RSpec.describe "Carreros", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "previews the carrero's commission as the purchase is typed, and hides it without one" do
    create(:hauler, person: create(:person, first_names: "Rubén", last_names: "Ordóñez"), commission_percent: 10, can_price: 50)
    visit new_trading_purchase_path
    expect(page).to have_no_text("Comisión del carrero")

    select "Uva", from: "purchase_coffee_state"
    fill_in "purchase_gross_weight", with: "1661"
    fill_in "purchase_yield_factor", with: "1"
    select "Rubén Ordóñez", from: "purchase_hauler_id"

    within("[data-hauler-commission-target='box']") do
      expect(page).to have_text("Comisión 10 % · lata a L 50.00")
      expect(page).to have_css("[data-hauler-commission-target='cans']", text: "100.00")
      expect(page).to have_css("[data-hauler-commission-target='amount']", text: "L 500.00")
    end

    fill_in "purchase_gross_weight", with: "836" # 830 lb net
    expect(page).to have_css("[data-hauler-commission-target='amount']", text: "L 251.52")

    select "Sin carrero", from: "purchase_hauler_id"
    expect(page).to have_no_text("Comisión del carrero")
  end

  it "asks a new carrero's percent and can price only while «Carrero» is checked" do
    visit new_administration_person_path
    fill_in "person_first_names", with: "Rubén"
    fill_in "person_last_names", with: "Ordóñez"
    expect(page).to have_no_field("person_hauler_commission_percent")

    check "person_hauler_role"
    expect(page).to have_field("person_hauler_commission_percent")
    find("main form [type=submit]").click
    expect(find("#person_hauler_commission_percent").evaluate_script("this.validationMessage")).to eq("Comisión (%) no puede estar en blanco")

    fill_in "person_hauler_commission_percent", with: "10"
    fill_in "person_hauler_can_price", with: "50"
    find("main form [type=submit]").click
    expect(page).to have_text("Persona creada.")
    expect(Person.last.hauler).to have_attributes(commission_percent: 10, can_price: 50)
  end
end
