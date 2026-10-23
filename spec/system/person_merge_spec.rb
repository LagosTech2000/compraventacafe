require "rails_helper"

# Merging a person registered twice, on screen (Fernando, 2026-10-14): pick
# the other one with the search, compare, choose detail by detail, merge.
RSpec.describe "Merging people", type: :system do
  let(:admin) { create(:user, :admin) }

  it "picks the other person, compares and merges with the details chosen" do
    kept = create(:producer, person: create(:person, first_names: "Ana María", last_names: "Zelaya", phone: "99990000"))
    other = create(:producer, person: create(:person, first_names: "Ana Maria", last_names: "Zelaya", dni: "0801199912345"))
    create(:farm, producer: other, name: "El Cerro")
    create(:purchase, producer: other)
    sign_in_as(admin)

    visit administration_person_path(kept.person)
    click_link "Fusionar con otra persona"
    expect(page).to have_css("h1", text: "Fusionar personas")
    pick_record "merge_other_search", other.picker_label
    click_button "Comparar"

    expect(page).to have_css(".data-card", text: /Queda.*Ana María Zelaya/im)
    within("#merge-field-dni") { expect(page).to have_checked_field(type: "radio", with: "secondary") }
    within("#merge-field-first_names") { choose "Nombres: el de Ana Maria Zelaya" }
    expect(page).to have_text("1 compra")
    expect(page).to have_text("1 finca")

    accept_confirm { click_button "Fusionar" }
    expect(page).to have_text("se fusionó en Ana Maria Zelaya")
    expect(kept.person.reload).to have_attributes(first_names: "Ana Maria", dni: "0801199912345", phone: "99990000")
    expect(kept.reload.farm_names).to eq("El Cerro")
    expect(Person.exists?(other.person_id)).to be(false)
  end

  it "asks to pick someone from the list before comparing" do
    person = create(:person, :client)
    sign_in_as(admin)
    visit new_administration_person_merge_path(person)
    fill_in "La otra persona", with: "Nadie así"
    expect(page).to have_text("No se encontró a nadie con ese nombre o número.")
    click_button "Comparar"
    expect(page).to have_current_path(new_administration_person_merge_path(person))
    expect(find_field("La otra persona").evaluate_script("this.validationMessage")).to eq("Selecciona una persona de la lista")
  end
end
