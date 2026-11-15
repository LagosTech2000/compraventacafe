require "rails_helper"

# A browser linked to a PC's fingerprint reader (Fernando, 2026-11-14;
# fingerprint.js): a finger fills the person field of the page, or goes to
# that person in a list, or opens the person's panel; registering a finger
# follows the bridge live. The bridge is played by FingerprintEvents.
RSpec.describe "Fingerprint reader", type: :system do
  let(:admin) { create(:user, :admin) }

  before do
    FingerprintStation.reset_states!
    FingerprintEnrollment.clear!
  end

  def link_station
    visit new_administration_fingerprint_station_path
    fill_in "fingerprint_station_name", with: "Caja"
    click_button "Agregar y ver el código"
    expect(page).to have_css("[data-pairing-code]")
    FingerprintStation.find_by!(name: "Caja")
  end

  # The page has subscribed once it shows a state it heard.
  def wait_for_reader(station)
    40.times do
      FingerprintChannel.broadcast_to(station, { type: "state", bridge: true, reader: true })
      return if page.has_css?("#fingerprint-status[data-state='ready']", wait: 0.25)
    end
    raise "the page never heard the reader"
  end

  def finger(station, fingerprint)
    FingerprintEvents.new(station).identified(fingerprint&.id, 80)
  end

  it "opens the person's panel, and says when a finger is not known" do
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    create(:purchase, producer:)
    fingerprint = create(:fingerprint, person: producer.person)
    sign_in_as(admin)
    station = link_station
    visit root_path
    wait_for_reader(station)
    expect(page).to have_css("#fingerprint-status", text: "Lector listo")

    finger(station, nil)
    expect(page).to have_css(".toast", text: "No se reconoce esa huella")

    finger(station, fingerprint)
    within("dialog[open]") do
      expect(page).to have_css("h1", text: "Ana Zelaya")
      expect(page).to have_css("nav .btn-primary", text: "Nueva compra")
      expect(page).to have_link("Facturar sus compras")
      expect(page).to have_text("Tiene 1 compra sin facturar.")
    end
  end

  it "fills the person field of the page instead" do
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    fingerprint = create(:fingerprint, person: producer.person)
    sign_in_as(admin)
    station = link_station
    visit new_trading_purchase_path
    wait_for_reader(station)

    finger(station, fingerprint)
    picker = find("[data-controller~='record-picker']", match: :first)
    expect(picker.find("input[role='combobox']").value).to start_with("Ana Zelaya")
    expect(picker.find("[data-record-picker-target='id']", visible: false).value).to eq(producer.id.to_s)
    expect(page).to have_no_css("dialog[open]")
  end

  it "picks the driver of a new shipment" do
    member = create(:staff_member, person: create(:person, :collaborator, first_names: "Luis", last_names: "Mejía"))
    fingerprint = create(:fingerprint, person: member.person)
    sign_in_as(admin)
    station = link_station
    visit new_sales_shipment_path
    wait_for_reader(station)

    finger(station, fingerprint)
    expect(page).to have_checked_field("shipment_transport_mode_driver")
    expect(page).to have_select("shipment_driver_id", selected: "Luis Mejía · #{member.role.name}")
  end

  it "goes to that producer's purchases to invoice from «Facturar compras»" do
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    create(:purchase, producer:)
    fingerprint = create(:fingerprint, person: producer.person)
    sign_in_as(admin)
    station = link_station
    visit new_trading_invoice_path
    wait_for_reader(station)

    finger(station, fingerprint)
    expect(page).to have_current_path(new_trading_invoice_path(producer_id: producer.id))
    expect(page).to have_text("Compras de Ana Zelaya sin facturar")
  end

  it "registers a finger, following the reader" do
    person = create(:person, first_names: "Ana", last_names: "Zelaya")
    sign_in_as(admin)
    station = link_station
    visit administration_person_path(person)
    click_link "Registrar huella"
    select "Pulgar derecho", from: "fingerprint_finger"
    check "fingerprint_consent"
    click_button "Empezar"
    expect(page).to have_text("Dedo: Pulgar derecho")
    expect(page).to have_text("Pon el dedo en el lector (1 de 3).")
    wait_for_reader(station)

    request_id = page.current_path.split("/").last
    events = FingerprintEvents.new(station)
    events.enroll_progress(request_id, 1)
    expect(page).to have_text("Pon el dedo en el lector (2 de 3).")
    expect(page).to have_css(".enroll-step.is-done", count: 1)

    events.enrolled(request_id, template: Base64.strict_encode64(Random.bytes(500)), duplicate_fid: nil)
    expect(page).to have_current_path(administration_person_path(person))
    expect(page).to have_css("#person-fingerprints ~ ul, ul", text: "Pulgar derecho")
    expect(person.fingerprints.sole.finger).to eq("right_thumb")
  end
end
