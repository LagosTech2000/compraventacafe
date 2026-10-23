require "rails_helper"

# The search behind a searchable picker (PickerSearch, Fernando, 2026-10-18):
# lists that grow are not loaded with the form; the page asks as the user types.
RSpec.describe "Picker searches" do
  let(:admin) { create(:user, :admin) }

  def user_with(**permissions)
    create(:user).tap do |user|
      permissions.each { |key, actions| create(:permission, user:, module_key: key.to_s, **Array(actions).to_h { |a| [ :"can_#{a}", true ] }) }
    end.reload
  end

  def search(kind, q, **params)
    get picker_search_path(kind), params: { q:, **params }, headers: { "Accept" => "application/json" }
    response.parsed_body
  end

  it "finds producers by any of their words, without accents, by DNI or by IHCAFE code" do
    ana = create(:producer, ihcafe_code: "AB-12-34567",
                            person: create(:person, first_names: "Ana", last_names: "Mejía Zelaya", dni: "0801199912345"))
    create(:producer, person: create(:person, first_names: "Bruno", last_names: "Aguilar"))
    sign_in admin

    expect(search(:producers, "mejia ana")["results"].pluck("id")).to eq([ ana.id ])
    expect(search(:producers, "08011999")["results"].pluck("id")).to eq([ ana.id ])
    expect(search(:producers, "AB-12")["results"].pluck("id")).to eq([ ana.id ])
    expect(search(:producers, ana.picker_label)["results"].pluck("id")).to eq([ ana.id ])
  end

  it "brings the producer's zone, missing details and active farms with theirs" do
    zone = create(:zone, name: "El Rosario")
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya", zone:))
    create(:farm, producer:, name: "La Loma", area_value: 3, area_unit: "manzana")
    create(:farm, producer:, name: "Vieja", active: false)
    sign_in admin

    result = search(:producers, "Zelaya")["results"].first

    expect(result).to include("id" => producer.id, "label" => "Ana Zelaya", "zone_id" => zone.id)
    expect(result["missing"]).to include("DNI", "Clave IHCAFE")
    expect(result["farms"]).to eq([ [ producer.farms.find_by(name: "La Loma").id, "La Loma", [ "Dirección", "Ubicación en el mapa" ] ] ])
  end

  it "answers nothing under 3 characters, and at most 20 with a note that there are more" do
    25.times { create(:person, first_names: "Carla") }
    sign_in admin

    expect(search(:people, "Ca")).to eq("results" => [], "more" => false)
    found = search(:people, "Carla")
    expect(found["results"].size).to eq(20)
    expect(found["more"]).to be(true)
  end

  it "leaves out the person being merged, and finds only collaborators for a payroll" do
    rosa = create(:person, first_names: "Rosa", last_names: "Díaz")
    worker = create(:person, :collaborator, first_names: "Rosa", last_names: "Cruz")
    sign_in admin

    expect(search(:people, "Rosa", except: rosa.id)["results"].pluck("id")).to eq([ worker.id ])
    expect(search(:collaborators, "Rosa")["results"].pluck("id")).to eq([ worker.id ])
  end

  it "lets search whoever can open a form that picks the kind, and nobody else" do
    create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))

    sign_in user_with(trading: :read)
    expect(search(:producers, "Zelaya")["results"].size).to eq(1)
    get picker_search_path(:people), params: { q: "Zelaya" }, headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:forbidden)

    sign_in user_with(farms: :create)
    expect(search(:producers, "Zelaya")["results"].size).to eq(1)
    expect(search(:collaborators, "Zelaya")["results"]).to eq([])

    sign_in user_with(loans: :create)
    expect(search(:people, "Zelaya")["results"].size).to eq(1)
    get picker_search_path(:producers), params: { q: "Zelaya" }, headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:forbidden)
  end

  it "does not know other kinds" do
    sign_in admin
    get "/picker_search/users", params: { q: "admin" }, headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:not_found)
  end

  it "keeps the lists out of the forms that pick from them" do
    create(:producer, person: create(:person, first_names: "Zacarías", last_names: "Escondido"))
    create(:person, :collaborator, first_names: "Tomasa", last_names: "Escondida")
    sign_in admin

    get new_trading_purchase_path
    expect(response.body).not_to include("Zacarías")
    get new_loans_loan_path
    expect(response.body).not_to include("Tomasa")
  end
end
