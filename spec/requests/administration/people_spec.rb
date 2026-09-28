require "rails_helper"

RSpec.describe "Administration::People" do
  def user_with(**flags)
    create(:user).tap { |u| create(:permission, user: u, module_key: "administration", **flags) }
  end

  let(:valid_params) do
    { person: { first_names: "Juan Carlos", last_names: "Mejía Reyes", dni: "0704200000968", phone: "9999-0000",
                email: "juan@example.com", address: "Aldea El Rosario", client_role: "1", collaborator_role: "1" } }
  end

  it "keeps a user without administration read out" do
    sign_in create(:user)
    get administration_people_path
    expect(response).to redirect_to(root_path)
  end

  context "as a reader" do
    before { sign_in user_with(can_read: true) }

    it "lists people with their roles" do
      create(:person, :client, first_names: "Rosa")
      get administration_people_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Rosa")
      expect(response.body).to include("Cliente")
      expect(response.body).not_to include(new_administration_person_path)
    end

    it "filters by role and searches" do
      create(:person, :client, first_names: "Rosa")
      create(:person, :collaborator, first_names: "Pedro")
      get administration_people_path(role: "collaborators")
      expect(response.body).to include("Pedro")
      expect(response.body).not_to include("Rosa")
      get administration_people_path(q: "ros")
      expect(response.body).to include("Rosa")
      expect(response.body).not_to include("Pedro")
    end

    it "shows a person without edit or delete buttons" do
      person = create(:person)
      get administration_person_path(person)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(edit_administration_person_path(person))
    end

    it "cannot create" do
      expect { post administration_people_path, params: valid_params }.not_to change(Person, :count)
    end
  end

  context "as a creator" do
    before { sign_in user_with(can_read: true, can_create: true) }

    it "creates a person with both roles" do
      expect { post administration_people_path, params: valid_params }.to change(Person, :count).by(1)
      person = Person.last
      expect(response).to redirect_to(administration_person_path(person))
      expect(person).to be_client
      expect(person).to be_collaborator
    end

    it "rejects a duplicate DNI with a Spanish message" do
      create(:person, dni: "0704200000968")
      expect { post administration_people_path, params: valid_params }.not_to change(Person, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("DNI ya está en uso")
    end

    it "saves a structured address" do
      department = Department.find_by!(code: "08")
      municipality = Municipality.find_by!(code: "0801")
      params = valid_params.deep_merge(person: { department_id: department.id, municipality_id: municipality.id, address_line: "Col. Kennedy" })
      post administration_people_path, params: params
      expect(Person.last).to have_attributes(department: department, municipality: municipality, address_line: "Col. Kennedy")
      follow_redirect!
      expect(response.body).to include("Col. Kennedy, Distrito Central, Francisco Morazán")
    end

    it "renders the form with browser validations and an empty municipality list" do
      get new_administration_person_path
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("#person_dni")["pattern"]).to be_present
      expect(page.at_css("#person_dni")["data-invalid-message"]).to eq("DNI debe tener 13 dígitos numéricos, sin letras")
      expect(page.at_css("#person_first_names")["required"]).to be_present
      expect(page.at_css("#person_email")["type"]).to eq("email")
      municipality = page.at_css("select#person_municipality_id")
      expect(municipality["disabled"]).to be_present
      expect(municipality.css("option").map(&:text)).to eq([ "Primero selecciona un departamento" ])
      expect(page.at_css("select#person_department_id option").text).to eq("Sin departamento asignado")
      expect(page.css("select#person_department_id option").size).to eq(19)
    end

    it "shows only the department's municipalities when re-rendering" do
      post administration_people_path, params: { person: { first_names: "", last_names: "", department_id: Department.find_by!(code: "11").id } }
      options = Nokogiri::HTML(response.body).css("select#person_municipality_id option").map(&:text)
      expect(options).to eq([ "Sin municipio asignado", "Guanaja", "José Santos Guardiola", "Roatán", "Utila" ])
    end

    it "shows Spanish errors when names are missing" do
      post administration_people_path, params: { person: { first_names: "", last_names: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Nombres no puede estar en blanco")
    end
  end

  context "as an editor" do
    before { sign_in user_with(can_read: true, can_update: true) }

    it "updates fields and removes a role" do
      person = create(:person, :client)
      patch administration_person_path(person), params: { person: { phone: "3333-4444", client_role: "0", collaborator_role: "0" } }
      expect(response).to redirect_to(administration_person_path(person))
      person.reload
      expect(person.phone).to eq("33334444")
      expect(person).not_to be_client
    end

    it "cannot delete" do
      person = create(:person)
      expect { delete administration_person_path(person) }.not_to change(Person, :count)
    end
  end

  context "as a destroyer" do
    before { sign_in user_with(can_read: true, can_destroy: true) }

    it "deletes a person and their roles" do
      person = create(:person, :client, :collaborator)
      expect { delete administration_person_path(person) }.to change(Person, :count).by(-1).and change(Client, :count).by(-1)
      expect(response).to redirect_to(administration_people_path)
    end
  end
end
