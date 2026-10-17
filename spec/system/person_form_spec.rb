require "rails_helper"

# The roles of a person form (person_roles_controller.js): at least one, said
# in Spanish before sending; the kind of producer only while "Productor" is
# checked. Every person form has them, and the zone.
RSpec.describe "Person form", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "asks for at least one role before sending, and the kind only for a producer" do
    create(:zone, name: "El Rosario")
    visit new_administration_person_path
    fill_in "person_first_names", with: "Rosa"
    fill_in "person_last_names", with: "Díaz"
    select "El Rosario", from: "person_zone_id"
    expect(page).to have_no_field("person_producer_kind")

    find("main form [type=submit]").click
    expect(find("#person_client_role").evaluate_script("this.validationMessage"))
      .to eq("Marca al menos un rol: cliente, colaborador, productor o carrero.")
    expect(Person.count).to eq(0)

    check "person_producer_role"
    select "Intermediario", from: "person_producer_kind"
    uncheck "person_producer_role"
    expect(page).to have_no_field("person_producer_kind")
    check "person_producer_role"
    find("main form [type=submit]").click

    expect(page).to have_text("Persona creada.")
    expect(Person.last).to have_attributes(full_name: "Rosa Díaz", zone: Zone.find_by(name: "El Rosario"))
    expect(Person.last.producer).to have_attributes(kind: "intermediary")
  end

  it "has the roles and the zone in the producer form, with Productor fixed" do
    visit new_trading_producer_path
    expect(page).to have_field("producer_person_attributes_zone_id")
    expect(page).to have_field("producer_person_attributes_producer_role", checked: true, disabled: true)

    fill_in "producer_person_attributes_first_names", with: "Carla"
    fill_in "producer_person_attributes_last_names", with: "Mejía"
    check "producer_person_attributes_client_role"
    find("main form [type=submit]").click
    expect(page).to have_text("Productor creado")
    expect(Producer.last.person).to have_attributes(client?: true, collaborator?: false)
  end
end
