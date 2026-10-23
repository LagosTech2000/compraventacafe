require "rails_helper"

# The forms that pick a person say which of their details are empty, with
# «Completar datos» in a modal (Fernando, 2026-10-18, like the producer's).
RSpec.describe "Person details missing", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "on a new loan, and updates the notice and the card once completed" do
    person = create(:person, :client, first_names: "Rosa", last_names: "Díaz", phone: "99990000")
    visit new_loans_loan_path
    pick_record "person_search", person.picker_label
    fill_in "loan_cash_amount", with: "1000"

    expect(page).to have_css("[role=status]", text: "A esta persona le faltan datos por ingresar: DNI, RTN, Correo electrónico, Zona, Dirección.")
    within("[data-record-gaps-target='notice']") { click_link "Completar datos" }
    within("dialog[open]") do
      fill_in "person_dni", with: "0801199912345"
      find("[type=submit]").click
    end

    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_css("[role=status]", text: "le faltan datos por ingresar: RTN, Correo electrónico, Zona, Dirección.")
    expect(page).to have_field("person_search", with: "Rosa Díaz — 0801199912345")
    expect(page).to have_field("loan_cash_amount", with: "1000")
    within("turbo-frame#borrower-card") { expect(page).to have_text("0801199912345") }
  end

  it "on a new employee of a payroll" do
    person = create(:person, :collaborator, first_names: "Tomás", last_names: "Cruz")
    payroll = create(:payroll)
    visit new_farms_payroll_member_path(payroll)
    pick_record "person_search", person.picker_label

    expect(page).to have_css("[role=status]", text: "A esta persona le faltan datos por ingresar: DNI, RTN, Teléfono")
  end
end
