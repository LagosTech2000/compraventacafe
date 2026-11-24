require "rails_helper"

# The remission of a shipment (Fernando, 2026-11-12): printed from the
# shipments with the fields of the client's booklet.
RSpec.describe "Sales remissions" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)
  def field(label) = page.css("[data-remission]").first.css("div").find { it.at_css("> dt")&.text == "#{label}:" }&.at_css("dd")&.text.to_s.strip

  before do
    SiteSetting.current.update!(business_name: "Compra de Café El Rey David", location: "Mata de Plátano, Morocelí",
                                rtn: "07041970002943", owner_name: "Emanuel Espinal Bonilla", phone: "9785-8796", secondary_phone: "95867270")
  end

  it "prints original and copy with the booklet's fields, from the shipment's data" do
    paraiso = Department.find_by!(name: "El Paraíso")
    buyer = create(:buyer, name: "Beneficio Betafe", department: paraiso, municipality: paraiso.municipalities.find_by!(name: "El Paraíso"))
    driver = create(:staff_member, :driver, person: create(:person, :collaborator, first_names: "Roberto", last_names: "Gallardo",
                                                                          phone: "99887766", dni: "0801199012345"))
    vehicle = create(:vehicle, vehicle_type: create(:vehicle_type, name: "Camión"), brand_model: "Isuzu NQR", color: "Blanco", plate: "JDE 6299")
    shipment = create(:shipment, buyer:, driver:, vehicle:, origin_sacks: 7,
                                 departed_at: Time.zone.local(2026, 11, 6, 8), observations: "Café de la bodega 1")
    sign_in admin

    get sales_shipment_remission_path(shipment)
    expect(response).to have_http_status(:ok)
    expect(page.css("[data-remission]").size).to eq(2)
    header = page.at_css("[data-remission] header").text.squish
    expect(header).to include("Compra de Café El Rey David", "De: Emanuel Espinal Bonilla", "Teléfonos: 9785-8796 / 9586-7270",
                              "RTN 07041970002943", "Remisión #{shipment.display_number}", "ORIGINAL")
    # Its number is the shipment's, and nothing calls it «salida N.º» (Fernando, 2026-11-13).
    expect(response.body).not_to match(/Salida \d/)
    expect(page.at_css("[data-place-date]").text.squish).to eq("Mata de Plátano, Morocelí, Vie 6 de noviembre de 2026")

    expect(field("Destino")).to include("El Paraíso")
    expect(field("Para")).to eq("Beneficio Betafe")
    expect(field("Sacos")).to eq("7")
    expect(field("Latas")).to eq("")
    expect(field("Equivalentes QQ oro")).to eq("")
    expect(field("Enviadas por")).to eq("Emanuel Espinal Bonilla")
    expect(field("Dirección")).to eq("Mata de Plátano, Morocelí")
    expect(field("Nombre de motorista")).to eq("Roberto Gallardo")
    expect(field("Teléfono")).to eq("9988-7766")
    expect(field("Identidad")).to eq("0801199012345")
    expect(field("Vehículo")).to eq("Camión")
    expect(field("Marca")).to eq("Isuzu NQR")
    expect(field("Color")).to eq("Blanco")
    expect(field("Placa No.")).to eq("JDE 6299")
    expect(response.body).to include("Café de la bodega 1", "Remisor", "Recibí conforme", "Motorista")
  end

  it "leaves what it does not know as lines to fill by hand" do
    shipment = create(:shipment, driver_name: "Pedro Lara")
    sign_in admin
    get sales_shipment_remission_path(shipment)
    expect(page.at_css("[data-remission] header").text).to include("Remisión #{shipment.display_number}")
    expect(field("Nombre de motorista")).to eq("Pedro Lara")
    expect(field("Teléfono")).to eq("")
    expect(field("Placa No.")).to eq("")
  end

  it "is opened from the shipment and from the list, except a voided one, and only by who sees the shipments" do
    shipment = create(:shipment)
    sign_in admin
    get sales_shipment_path(shipment)
    expect(page.css("a").map { it["href"] }).to include(sales_shipment_remission_path(shipment))
    get sales_shipments_path
    expect(page.css("a").map { it["href"] }).to include(sales_shipment_remission_path(shipment))

    shipment.update_columns(voided_at: Time.current, voided_by_id: admin.id)
    get sales_shipment_path(shipment)
    expect(page.css("a").map { it["href"] }).not_to include(sales_shipment_remission_path(shipment))

    other = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "sales", can_read: true) }
    sign_in other
    get sales_shipment_remission_path(shipment)
    expect(response).to redirect_to(root_path)
  end
end
