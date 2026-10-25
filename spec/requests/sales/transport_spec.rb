require "rails_helper"

# Carriers and trucks (Fernando, 2026-10-25): two catalogs of their own,
# chosen in a shipment with its driver (an employee or a name typed).
RSpec.describe "Sales carriers and trucks" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "registers carriers and trucks, lists them and shows their shipments" do
    post sales_carriers_path, params: { carrier: { name: " Transportes  Rápidos ", rtn: "0801-1999-123456", phone: "9999-0000", contact_name: "Mario" } }
    carrier = Carrier.sole
    expect(carrier).to have_attributes(name: "Transportes Rápidos", rtn: "08011999123456", phone: "99990000")
    expect(AuditEvent.where(auditable: carrier, action: "create")).to exist

    post sales_trucks_path, params: { truck: { plate: "haa  1234", brand_model: "Isuzu NPR", capacity_quintals: "80", own: "1" } }
    truck = Truck.sole
    expect(truck).to have_attributes(plate: "HAA 1234", own: true)
    post sales_trucks_path, params: { truck: { plate: "HAA 1234" } }
    expect(response).to have_http_status(:unprocessable_content)

    shipment = create(:shipment, carrier:, truck:)
    get sales_carriers_path
    expect(page.at_css("#carrier_#{carrier.id}").text.squish).to include("Transportes Rápidos", "Mario", "9999-0000", "1")
    get sales_trucks_path(owner: "own")
    expect(page.at_css("#truck_#{truck.id}").text.squish).to include("HAA 1234", "Isuzu NPR", "80.00", "Del negocio")
    get sales_carrier_path(carrier)
    expect(response.body).to include("Salida #{shipment.display_number}")
    get sales_truck_path(truck)
    expect(response.body).to include("Salida #{shipment.display_number}")

    patch sales_carrier_path(carrier), params: { carrier: { active: "0" } }
    expect(carrier.reload).not_to be_active
    expect(build(:shipment, carrier:)).not_to be_valid
  end

  it "takes the carrier, truck and driver in a shipment, and searches by them" do
    carrier = create(:carrier, name: "Fletes del Norte")
    truck = create(:truck, plate: "HBB 4321")
    driver = create(:staff_member, role: create(:staff_role, name: "Chofer"), person: create(:person, :collaborator, first_names: "David", last_names: "Cruz"))

    get new_sales_shipment_path
    expect(page.css("#shipment_carrier_id option").map(&:text)).to include("Fletes del Norte")
    expect(page.css("#shipment_driver_id option").map(&:text)).to include("David Cruz · Chofer")

    shipment = create(:shipment, carrier:, truck:, driver:, driver_name: "Otro")
    expect(shipment).to have_attributes(driver_name: nil, driver_label: "David Cruz")
    typed = create(:shipment, driver_name: "  Juan  Pérez ")
    expect(typed.driver_label).to eq("Juan Pérez")

    get sales_shipment_path(shipment)
    expect(page.at_css("#shipment-details").parent.text.squish).to include("TransportistaFletes del Norte", "CamiónHBB 4321", "MotoristaDavid Cruz")

    get sales_shipments_path(q: "HBB")
    expect(response.body).to include("Salida #{shipment.display_number}")
    expect(response.body).not_to include("Salida #{typed.display_number}")
    get sales_shipments_path(carrier_id: carrier.id)
    expect(response.body).to include("Salida #{shipment.display_number}")
  end
end
