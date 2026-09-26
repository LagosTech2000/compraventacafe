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
      expect(person.phone).to eq("3333-4444")
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
