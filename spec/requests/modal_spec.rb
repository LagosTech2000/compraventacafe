require "rails_helper"

RSpec.describe "Modal frame" do
  let(:modal) { { "Turbo-Frame" => "modal" } }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "is in every page, empty until a link opens it" do
    get root_path
    frame = Nokogiri::HTML(response.body).at_css("dialog[data-controller='modal'] turbo-frame#modal")
    expect(frame).to be_present
    expect(frame["src"]).to be_nil
  end

  it "renders pages requested by the frame with the modal layout, without navigation" do
    get trading_producer_path(create(:producer)), headers: modal
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("turbo-frame#modal button[data-action='modal#close']")).to be_present
    expect(page.at_css("header nav")).to be_nil
    expect(response.body).not_to include("Volver a productores")
  end

  it "opens details with a Detalle button on every list" do
    create(:invoice)
    create(:person)
    {
      administration_users_path => "user", administration_people_path => "person",
      trading_producers_path => "producer", trading_purchases_path => "purchase",
      trading_invoices_path => "invoice", administration_audit_events_path => "audit_event"
    }.each do |path, _|
      get path
      button = Nokogiri::HTML(response.body).css("a[data-turbo-frame='modal']").find { |a| a.text == "Detalle" }
      expect(button).to be_present, "no Detalle button on #{path}"
    end
  end

  it "closes and refreshes the page behind after a normal save" do
    post trading_zones_path, params: { zone: { name: "Pueblo Nuevo" } }, headers: modal
    result = Nokogiri::HTML(response.body).at_css("[data-controller='modal-result']")
    expect(result["data-modal-result-event-value"]).to eq("zone:created")
    expect(result["data-modal-result-refresh-value"]).to eq("true")
    expect(flash[:notice]).to eq("Zona creada.")
  end

  it "keeps validation errors inside the modal" do
    post trading_zones_path, params: { zone: { name: "" } }, headers: modal
    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal #form-errors")).to be_present
  end

  it "shows a forbidden action as an alert inside the modal" do
    sign_in create(:user)
    get trading_producer_path(create(:producer)), headers: modal
    expect(response).to have_http_status(:forbidden)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("turbo-frame#modal [role='alert']").text).to include("No tienes permiso")
  end

  it "closes with a button instead of navigating away when cancelling" do
    get new_trading_zone_path, headers: modal
    expect(Nokogiri::HTML(response.body).at_css("button[data-action='modal#close']", text: "Cancelar")).to be_present
  end
end
