require "rails_helper"

# The driver in the shipment form (Fernando, 2026-11-13): «Editar» to the
# right of the select opens their person, and their identity and phone
# show below, ready for the remission.
RSpec.describe "Shipment driver", type: :system do
  let(:admin) { create(:user, :admin) }

  it "shows the driver's identity and phone, and completes them in the modal without losing the shipment" do
    driver = create(:staff_member, person: create(:person, :collaborator, first_names: "Roberto", last_names: "Gallardo", phone: "99887766"))
    sign_in_as(admin)
    visit new_sales_shipment_path
    choose "Un motorista"
    expect(page).to have_no_link("Editar")

    fill_in "shipment_observations", with: "Sale temprano"
    select "Roberto Gallardo", from: "shipment_driver_id"
    within("turbo-frame#driver-card") do
      expect(page).to have_css("[data-driver-phone]", text: "9988-7766")
      expect(page).to have_css("[data-driver-identity]", text: "—")
      expect(page).to have_text("Le falta: Identidad")
    end

    click_link "Editar"
    within("dialog[open]") do
      fill_in "person_dni", with: "0801199012345"
      find("[type=submit]").click
    end
    within("turbo-frame#driver-card") { expect(page).to have_css("[data-driver-identity]", text: "0801199012345") }
    expect(page).to have_field("shipment_observations", with: "Sale temprano")
    expect(driver.person.reload.dni).to eq("0801199012345")
  end
end
