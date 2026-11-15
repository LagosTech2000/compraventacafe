require "rails_helper"

# Fingerprints read with a ZK9500 (Fernando, 2026-11-14): the PCs with a
# reader, what their bridge asks, registering a finger (administrators, with
# consent) and the panel of the person a finger belongs to.
RSpec.describe "Fingerprints" do
  let(:admin) { create(:user, :admin) }

  before do
    FingerprintStation.reset_states!
    FingerprintEnrollment.clear!
  end

  describe "the PCs with a reader" do
    before { sign_in admin }

    it "adds one from this browser, which is linked to it, and shows the bridge's code once" do
      post administration_fingerprint_stations_path, params: { fingerprint_station: { name: " Caja " } }
      station = FingerprintStation.last
      expect(response).to redirect_to(administration_fingerprint_station_path(station))
      follow_redirect!

      code = Nokogiri::HTML(response.body).at_css("[data-pairing-code]").text
      expect(FingerprintStation.pair!(code)&.first).to eq(station)
      expect(station.reload.name).to eq("Caja")
      expect(response.body).to include("este navegador está enlazado")
      expect(response.body).to include(%(<meta name="fingerprint-station" content="#{station.id}"))
      expect(response.body).to include("Programa del lector apagado")

      get administration_fingerprint_station_path(station)
      expect(response.body).not_to include("data-pairing-code")

      get administration_root_path
      expect(response.body).to include(%(href="#{administration_fingerprint_stations_path}"), "Lectores de huella")
    end

    it "gives a new code, links another browser and deactivates it" do
      station = create(:fingerprint_station, :paired)
      post pairing_administration_fingerprint_station_path(station)
      follow_redirect!
      expect(response.body).to include("data-pairing-code")
      expect(response.body).to include("este navegador no está enlazado")

      patch link_administration_fingerprint_station_path(station)
      follow_redirect!
      expect(response.body).to include("este navegador está enlazado")

      delete administration_fingerprint_station_path(station)
      expect(station.reload).to have_attributes(active: false, token_digest: nil)
      get administration_fingerprint_stations_path
      expect(response.body).to include("Desactivado")
      expect(response.body).not_to include(%(name="fingerprint-station"))
    end

    it "is for administrators only" do
      station = create(:fingerprint_station)
      user = create(:user).tap { create(:permission, user: it, module_key: "administration", can_read: true, can_create: true, can_update: true, can_destroy: true) }
      sign_in user

      get administration_root_path
      expect(response.body).not_to include(administration_fingerprint_stations_path)
      get administration_fingerprint_stations_path
      expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")
      patch link_administration_fingerprint_station_path(station)
      expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")
      get administration_person_path(create(:person))
      expect(response.body).not_to include("Registrar huella")
    end
  end

  describe "what the bridge asks" do
    let(:station) { create(:fingerprint_station) }

    it "pairs with the code and loads the templates with its token" do
      station.start_pairing!
      post fingerprint_bridge_pairing_path, params: { code: station.pairing_code }, as: :json
      token = response.parsed_body["token"]
      expect(response.parsed_body["station"]).to eq(station.name)

      fingerprint = create(:fingerprint)
      get fingerprint_bridge_templates_path, headers: { "Authorization" => "Bearer #{token}" }
      expect(response.parsed_body["templates"]).to eq([ { "id" => fingerprint.id, "template" => fingerprint.template } ])
      expect(station.reload.last_seen_at).to be_present
    end

    it "turns away a wrong code and a missing or old token" do
      post fingerprint_bridge_pairing_path, params: { code: "000000" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      get fingerprint_bridge_templates_path
      expect(response).to have_http_status(:unauthorized)

      station.start_pairing!
      _, token = FingerprintStation.pair!(station.pairing_code)
      station.reload.deactivate!
      get fingerprint_bridge_templates_path, headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "registering a finger" do
    let(:person) { create(:person) }

    before { sign_in admin }

    it "asks for a browser linked to a reader" do
      get new_administration_person_fingerprint_path(person)
      expect(response.body).to include("Este navegador no está enlazado a un lector de huella")

      post administration_person_fingerprints_path(person), params: { fingerprint: { finger: "right_index", consent: "1" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "asks the person's consent, then tells the bridge to take the finger" do
      post administration_fingerprint_stations_path, params: { fingerprint_station: { name: "Caja" } }
      station = FingerprintStation.last

      get new_administration_person_fingerprint_path(person)
      option = Nokogiri::HTML(response.body).at_css("#fingerprint_finger option[selected]")
      expect([ option["value"], option.text ]).to eq([ "right_index", "Índice derecho (recomendado)" ])

      post administration_person_fingerprints_path(person), params: { fingerprint: { finger: "right_index", consent: "0" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("la persona tiene que aceptar")

      expect { post administration_person_fingerprints_path(person), params: { fingerprint: { finger: "left_thumb", consent: "1" } } }
        .to have_broadcasted_to(station).from_channel(FingerprintBridgeChannel).with(hash_including(type: "enroll", person: person.full_name, finger: "Pulgar izquierdo"))
      expect(response).to redirect_to(%r{/administration/people/#{person.id}/fingerprints/[0-9a-f-]+\?finger=left_thumb})
      follow_redirect!
      expect(response.body).to include("Dedo: Pulgar izquierdo")
    end

    it "lists the person's fingers and removes one" do
      fingerprint = create(:fingerprint, person:, finger: "left_index")
      get administration_person_path(person)
      expect(response.body).to include("Índice izquierdo")

      delete administration_person_fingerprint_path(person, fingerprint)
      expect(person.fingerprints.reload).to be_empty
      expect(flash[:notice]).to eq("Se quitó la huella: Índice izquierdo.")
    end

    it "moves its fingerprints when merging people, keeping the primary's finger" do
      other = create(:person)
      create(:fingerprint, person:, finger: "right_index")
      create(:fingerprint, person: other, finger: "right_index")
      moved = create(:fingerprint, person: other, finger: "left_thumb")

      merge = PersonMerge.new(primary: person, secondary: other)
      expect(merge.save).to be(true)
      expect(person.fingerprints.reload.map(&:finger)).to contain_exactly("right_index", "left_thumb")
      expect(moved.reload.person).to eq(person)
    end
  end

  describe "the panel of the person a finger belongs to" do
    it "shows a producer's pending purchases and the shortcuts the user may use" do
      producer = create(:producer)
      create(:purchase, producer:)
      sign_in admin

      get person_panel_path(producer.person), headers: { "Turbo-Frame" => "modal" }
      body = response.body
      expect(body).to include(producer.full_name, "Tiene 1 compra sin facturar.")
      expect(body).to include(new_trading_purchase_path(producer_id: producer.id), new_trading_invoice_path(producer_id: producer.id))
      expect(body).to include(%(src="#{trading_producer_card_path(producer)}"))
      expect(Nokogiri::HTML(body).at_css("[data-person-panel] nav .btn-primary").text).to eq("Nueva compra")
    end

    it "offers a payment to someone who only owes loans, to whoever sees Préstamos" do
      user = create(:user).tap { create(:permission, user: it, module_key: "loans", can_read: true, can_create: true, can_update: true) }
      sign_in user
      loan = create(:loan, due_on: Time.zone.today - 1, disbursed_on: Time.zone.today - 30)

      get person_panel_path(loan.person)
      body = response.body
      expect(body).to include("Tiene 1 préstamo vencido.", new_loans_loan_payment_path(loan), loans_credit_account_path(loan.person))
      shortcuts = Nokogiri::HTML(body).css("[data-person-panel] nav a").map(&:text)
      expect(shortcuts).to eq([ "Registrar abono", "Nuevo préstamo", "Estado de cuenta" ])
    end

    it "offers paying a hauler and a shipment with a driver" do
      hauler = create(:hauler, person: create(:person, :collaborator))
      producer = create(:producer)
      create(:purchase, producer:, hauler:)
      member = create(:staff_member, person: hauler.person)
      sign_in admin

      get person_panel_path(hauler.person)
      expect(response.body).to include(new_trading_hauler_payment_path(hauler), "Por pagarle en comisiones", new_sales_shipment_path(driver_id: member.id))

      get new_sales_shipment_path(driver_id: member.id)
      expect(Nokogiri::HTML(response.body).at_css("#shipment_driver_id option[selected]")["value"]).to eq(member.id.to_s)
      expect(Nokogiri::HTML(response.body).at_css("#shipment_transport_mode_driver")["checked"]).to eq("checked")
    end

    it "gives a page what its fields need, only for what the user may search" do
      producer = create(:producer)
      sign_in admin
      get fingerprint_match_path(producer.person)
      expect(response.parsed_body).to include("person_id" => producer.person_id, "producer_id" => producer.id, "panel_url" => person_panel_path(producer.person))
      expect(response.parsed_body["pickers"].keys).to contain_exactly("producers", "people")

      buyer = create(:user).tap { create(:permission, user: it, module_key: "trading", submodule_key: "purchases", can_read: true) }
      sign_in buyer
      get fingerprint_match_path(producer.person)
      expect(response.parsed_body["pickers"].keys).to eq([ "producers" ])
    end
  end
end
