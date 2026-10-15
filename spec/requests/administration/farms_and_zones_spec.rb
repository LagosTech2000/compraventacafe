require "rails_helper"

# Farms and zones from Administración (Fernando, 2026-10-14), with the
# Administración permissions, and a producer's record from its person.
RSpec.describe "Administración: fincas, zonas y productores" do
  def page = Nokogiri::HTML(response.body)

  def admin_user(**flags)
    create(:user).tap { |user| create(:permission, user:, module_key: "administration", can_read: true, **flags) }
  end

  describe "farms" do
    it "lists, creates, edits and deletes farms with Administración permissions only" do
      producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
      sign_in admin_user(can_create: true, can_update: true, can_destroy: true)

      get administration_farms_path
      expect(response).to have_http_status(:ok)
      post administration_farms_path, params: { farm: { name: "El Roble", producer_id: producer.id, area_value: "3", area_unit: "manzana" } }
      farm = Farm.find_by!(name: "El Roble")
      expect(farm).to have_attributes(producer:, area_value: 3, area_unit: "manzana")

      get administration_farms_path
      expect(page.at_css("tr##{ActionView::RecordIdentifier.dom_id(farm)}").text.squish).to include("El Roble", "Ana Zelaya", "3 mz")
      get administration_farm_path(farm)
      expect(response.body).to include("Borrar")

      patch administration_farm_path(farm), params: { farm: { name: "El Roble Viejo" } }
      expect(farm.reload.name).to eq("El Roble Viejo")
      delete administration_farm_path(farm)
      expect(Farm.exists?(farm.id)).to be(false)
      expect(AuditEvent.where(auditable_type: "Farm", action: "destroy")).to exist
    end

    it "does not delete a farm that purchases or payrolls name" do
      farm = create(:farm)
      create(:payroll, farm:)
      sign_in admin_user(can_destroy: true)

      get administration_farm_path(farm)
      expect(page.css("form[action='#{administration_farm_path(farm)}']")).to be_empty
      delete administration_farm_path(farm)
      expect(flash[:alert]).to include("No se puede borrar")
      expect(Farm.exists?(farm.id)).to be(true)
    end

    it "refuses whoever lacks the Administración permission, even with Fincas" do
      user = create(:user).tap { |u| create(:permission, user: u, module_key: "farms", can_read: true, can_create: true) }
      sign_in user
      get administration_farms_path
      expect(response).to redirect_to(root_path)
      post administration_farms_path, params: { farm: { name: "Nope" } }
      expect(Farm.exists?(name: "Nope")).to be(false)

      sign_in admin_user
      post administration_farms_path, params: { farm: { name: "Nope" } }
      expect(Farm.exists?(name: "Nope")).to be(false)
    end

    it "sorts every column of the list" do
      create(:farm, producer: create(:producer), area_value: 1, area_unit: "hectare")
      create(:farm)
      sign_in create(:user, :admin)
      get administration_farms_path
      headers = page.css("table.data-table thead th").reject { it["class"].to_s.include?("cell-actions") }
      expect(headers).to all(satisfy { it.at_css("a.sort-link") })
      FarmFilter.sortings.each_key do |key|
        %w[asc desc].each do |dir|
          get administration_farms_path(sort: key, dir:)
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe "zones" do
    it "creates, renames and deletes a zone not in use, and keeps one in use" do
      sign_in admin_user(can_create: true, can_update: true, can_destroy: true)
      post administration_zones_path, params: { zone: { name: "El Rosario" } }
      zone = Zone.find_by!(name: "El Rosario")
      patch administration_zone_path(zone), params: { zone: { name: "El Rosario Arriba" } }
      expect(zone.reload.name).to eq("El Rosario Arriba")

      used = create(:zone, name: "Usada")
      create(:person, zone: used)
      get administration_zones_path
      row = ->(record) { page.at_css("tr##{ActionView::RecordIdentifier.dom_id(record)}") }
      expect(row.(zone).text).to include("Borrar")
      expect(row.(used).text.squish).to include("Usada 1 0")
      expect(row.(used).text).not_to include("Borrar")

      delete administration_zone_path(used)
      expect(flash[:alert]).to include("No se puede borrar")
      delete administration_zone_path(zone)
      expect(Zone.exists?(zone.id)).to be(false)
    end

    it "sorts every column of the list" do
      create(:person, zone: create(:zone))
      sign_in create(:user, :admin)
      get administration_zones_path
      headers = page.css("table.data-table thead th").reject { it["class"].to_s.include?("cell-actions") }
      expect(headers).to all(satisfy { it.at_css("a.sort-link") })
      ZoneFilter.sortings.each_key do |key|
        %w[asc desc].each do |dir|
          get administration_zones_path(sort: key, dir:)
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe "a producer from its person" do
    it "shows the person as a producer with its farms, and edits the producer with Administración permissions" do
      producer = create(:producer, ihcafe_code: "AB-12-34567")
      farm = create(:farm, producer:, name: "La Loma", area_value: 2, area_unit: "manzana")
      create(:purchase, producer:, farm:, gross_weight: 146)
      sign_in admin_user(can_update: true)

      get administration_person_path(producer.person)
      section = page.at_css("[aria-labelledby=person-producer]")
      expect(section.text.squish).to include("Como productor", "AB-12-34567", "0.57", "La Loma", "2 mz", "Editar productor")
      expect(section.text).not_to include("Abrir en Compra de café") # no Compra de café permission

      get edit_administration_producer_path(producer)
      expect(response).to have_http_status(:ok)
      patch administration_producer_path(producer), params: { producer: { kind: "intermediary", ihcafe_code: "CD-34-56789",
                                                                          new_farm_names: [ "El Cerro" ],
                                                                          person_attributes: { id: producer.person.id, first_names: "Ana María" } } }
      expect(response).to redirect_to(administration_person_path(producer.person))
      expect(producer.reload).to have_attributes(kind: "intermediary", ihcafe_code: "CD-34-56789", farm_names: "El Cerro, La Loma")
      expect(producer.person.first_names).to eq("Ana María")
    end

    it "does not let a reader edit the producer" do
      producer = create(:producer)
      sign_in admin_user
      patch administration_producer_path(producer), params: { producer: { kind: "intermediary" } }
      expect(producer.reload.kind).to eq("producer")
    end
  end
end
