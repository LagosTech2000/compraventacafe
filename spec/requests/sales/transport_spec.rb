require "rails_helper"

# Carriers and vehicles (Fernando, 2026-10-25): two catalogs of their own,
# chosen in a shipment with its driver (an employee or a name typed). Each
# vehicle has its type, from a catalog of its own (Fernando, 2026-11-04).
RSpec.describe "Sales carriers and vehicles" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "registers carriers and vehicles, lists them and shows their shipments" do
    post sales_carriers_path, params: { carrier: { name: " Transportes  Rápidos ", rtn: "0801-1999-123456", phone: "9999-0000", contact_name: "Mario" } }
    carrier = Carrier.sole
    expect(carrier).to have_attributes(name: "Transportes Rápidos", rtn: "08011999123456", phone: "99990000")
    expect(AuditEvent.where(auditable: carrier, action: "create")).to exist

    pickup = create(:vehicle_type, name: "Pick-up")
    post sales_vehicles_path, params: { vehicle: { plate: "haa  1234", brand_model: "Isuzu NPR", capacity_quintals: "80", own: "1" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Tipo no puede estar en blanco")
    post sales_vehicles_path, params: { vehicle: { vehicle_type_id: pickup.id, plate: "haa  1234", brand_model: "Isuzu NPR", capacity_quintals: "80", own: "1" } }
    vehicle = Vehicle.sole
    expect(vehicle).to have_attributes(plate: "HAA 1234", own: true, vehicle_type: pickup, label: "HAA 1234 · Pick-up · Isuzu NPR")
    post sales_vehicles_path, params: { vehicle: { vehicle_type_id: pickup.id, plate: "HAA 1234" } }
    expect(response).to have_http_status(:unprocessable_content)

    shipment = create(:shipment, carrier:, vehicle:)
    get sales_carriers_path
    expect(page.at_css("#carrier_#{carrier.id}").text.squish).to include("Transportes Rápidos", "Mario", "9999-0000", "1")
    get sales_vehicles_path(owner: "own")
    expect(page.at_css("#vehicle_#{vehicle.id}").text.squish).to include("HAA 1234", "Pick-up", "Isuzu NPR", "80.00", "Del negocio")
    get sales_vehicles_path(vehicle_type_id: create(:vehicle_type).id)
    expect(page.at_css("#vehicle_#{vehicle.id}")).to be_nil
    get sales_carrier_path(carrier)
    expect(response.body).to include("Salida #{shipment.display_number}")
    get sales_vehicle_path(vehicle)
    expect(response.body).to include("Salida #{shipment.display_number}", "Pick-up")

    patch sales_carrier_path(carrier), params: { carrier: { active: "0" } }
    expect(carrier.reload).not_to be_active
    expect(build(:shipment, carrier:)).not_to be_valid
  end

  it "takes the carrier, vehicle and driver in a shipment, and searches by them" do
    carrier = create(:carrier, name: "Fletes del Norte")
    vehicle = create(:vehicle, plate: "HBB 4321")
    driver = create(:staff_member, role: create(:staff_role, name: "Chofer"), person: create(:person, :collaborator, first_names: "David", last_names: "Cruz"))

    get new_sales_shipment_path
    expect(page.css("#shipment_carrier_id option").map(&:text)).to include("Fletes del Norte")
    expect(page.css("#shipment_driver_id option").map(&:text)).to include("David Cruz · Chofer")

    shipment = create(:shipment, carrier:, vehicle:)
    driven = create(:shipment, driver:, driver_name: "Otro")
    expect(driven).to have_attributes(driver_name: nil, driver_label: "David Cruz")
    typed = create(:shipment, driver_name: "  Juan  Pérez ")
    expect(typed.driver_label).to eq("Juan Pérez")

    get sales_shipment_path(shipment)
    expect(page.at_css("#shipment-details").parent.text.squish).to include("TransportistaFletes del Norte", "VehículoHBB 4321")
    get sales_shipment_path(driven)
    expect(page.at_css("#shipment-details").parent.text.squish).to include("MotoristaDavid Cruz")

    get sales_shipments_path(q: "HBB")
    expect(response.body).to include("Salida #{shipment.display_number}")
    expect(response.body).not_to include("Salida #{typed.display_number}")
    get sales_shipments_path(carrier_id: carrier.id)
    expect(response.body).to include("Salida #{shipment.display_number}")
  end

  describe "vehicle types" do
    it "registers, renames and deactivates them, audited, and lists how many vehicles each has" do
      post sales_vehicle_types_path, params: { vehicle_type: { name: "  Pick-up " } }
      pickup = VehicleType.sole
      expect(pickup.name).to eq("Pick-up")
      expect(AuditEvent.where(auditable: pickup, action: "create")).to exist
      post sales_vehicle_types_path, params: { vehicle_type: { name: "pick-up" } }
      expect(response).to have_http_status(:unprocessable_content)

      create(:vehicle, vehicle_type: pickup)
      get sales_vehicle_types_path
      expect(page.at_css("#vehicle_type_#{pickup.id}").text.squish).to include("Pick-up", "1")

      patch sales_vehicle_type_path(pickup), params: { vehicle_type: { name: "Pickup", active: "0" } }
      expect(pickup.reload).to have_attributes(name: "Pickup", active: false)
      get sales_vehicle_types_path
      expect(page.at_css("#vehicle_type_#{pickup.id}")).to be_nil
      get sales_vehicle_types_path(status: "inactive")
      expect(page.at_css("#vehicle_type_#{pickup.id}").text).to include("Pickup")
    end

    it "offers only the active ones for a new vehicle, and a vehicle keeps a deactivated one" do
      truck = create(:vehicle_type, name: "Camión")
      old = create(:vehicle_type, name: "Carreta")
      vehicle = create(:vehicle, vehicle_type: old)
      old.update!(active: false)

      get new_sales_vehicle_path
      expect(page.css("#vehicle_vehicle_type_id option").map(&:text)).to eq([ "Selecciona el tipo de vehículo", "Camión" ])
      get edit_sales_vehicle_path(vehicle)
      expect(page.css("#vehicle_vehicle_type_id option").map(&:text)).to include("Carreta")
      expect(vehicle.update(color: "Blanco")).to be(true)

      other = build(:vehicle, vehicle_type: old)
      expect(other).not_to be_valid
      expect(other.errors.full_messages).to include("Tipo está desactivado: elige otro")
      expect(build(:vehicle, vehicle_type: truck)).to be_valid
    end

    it "is a sales record: a user without Comercialización cannot see them" do
      sign_in create(:user)
      get sales_vehicle_types_path
      expect(response).to redirect_to(root_path)
    end
  end

  # Client, 2026-10-30: a carrier or a driver, one or the other, and what
  # the carrier is paid for the trip.
  describe "a carrier or a driver, with the trip price" do
    let(:buyer) { create(:buyer) }
    let(:carrier) { create(:carrier, name: "Fletes del Norte") }

    def shipment_params(**extra)
      { buyer_id: buyer.id, departed_at: Time.current.strftime("%Y-%m-%dT%H:%M"), coffee_state: "wet_parchment", origin_weight_mode: "single",
        origin_gross_weight: "1000", origin_sacks: "6", origin_humidity_percent: "51", **extra }
    end

    it "keeps the carrier and its trip price, and clears the driver typed" do
      create(:purchase, gross_weight: 2_000)
      post sales_shipments_path, params: { shipment: shipment_params(transport_mode: "carrier", carrier_id: carrier.id, trip_price: "3500", driver_name: "Juan") }
      shipment = Shipment.sole
      expect(shipment).to have_attributes(carrier:, trip_price: 3_500, driver_name: nil, driver_id: nil)

      get sales_shipment_path(shipment)
      expect(page.at_css("#shipment-details").parent.text.squish).to include("Precio del viaje (L)L 3,500.00")
      get sales_carrier_path(carrier)
      expect(response.body).to include("L 3,500.00 en 1 viaje")
    end

    it "keeps the driver and clears the carrier and its price" do
      post sales_shipments_path, params: { shipment: shipment_params(transport_mode: "driver", carrier_id: carrier.id, trip_price: "3500", driver_name: "Juan") }
      expect(Shipment.sole).to have_attributes(carrier: nil, trip_price: nil, driver_name: "Juan")
    end

    it "refuses both at once and a trip price that is not a positive amount" do
      expect(build(:shipment, carrier:, driver_name: "Juan")).not_to be_valid
      shipment = build(:shipment, carrier:, driver_name: "Juan")
      shipment.valid?
      expect(shipment.errors[:base]).to include("Lleva un transportista o un motorista, no los dos.")
      expect(build(:shipment, carrier:, trip_price: 0)).not_to be_valid
    end

    it "shows the number the new shipment will take" do
      create(:shipment)
      get new_sales_shipment_path
      expect(page.at_css("#next-shipment-number").text).to eq("Salida No. #{format("%04d", Shipment.maximum(:number) + 1)}")
    end
  end
end
