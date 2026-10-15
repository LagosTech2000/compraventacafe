require "rails_helper"

RSpec.describe "Site settings" do
  let(:admin) { create(:user, :admin) }

  def logo(name, type) = fixture_file_upload(name, type)

  it "changes the business name and location everywhere they show" do
    sign_in admin
    get administration_site_setting_path
    expect(response.body).to include("Compra de Café el Rey David")

    patch administration_site_setting_path, params: { site_setting: { business_name: "Café La Esperanza", location: "Danlí, El Paraíso" } }
    expect(response).to redirect_to(administration_site_setting_path)

    get root_path
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("header nav").text).to include("Café La Esperanza")
    expect(page.at_css("title").text).to end_with("Café La Esperanza")

    delete session_path
    get new_session_path
    expect(response.body).to include("Café La Esperanza", "Danlí, El Paraíso")
  end

  it "keeps the business's RTN (14 digits, optional) and prints it on invoices only" do
    sign_in admin
    patch administration_site_setting_path, params: { site_setting: { business_name: "Rey David", rtn: "0801-1999-123456" } }
    expect(response).to redirect_to(administration_site_setting_path)
    expect(SiteSetting.sole.rtn).to eq("08011999123456")

    get administration_site_setting_path
    expect(response.body).to include("RTN del negocio", "08011999123456")

    invoice = create(:invoice)
    get trading_invoice_path(invoice)
    rtns = Nokogiri::HTML(response.body).css("header.border-b-2 [data-business-rtn]")
    expect(rtns.map { |line| line.text.squish }).to eq([ "RTN 08011999123456" ] * 2) # original and copy

    get loans_loan_payment_path(*create(:loan_payment).then { [ it.loan, it ] })
    expect(response.body).not_to include("data-business-rtn")

    patch administration_site_setting_path, params: { site_setting: { business_name: "Rey David", rtn: "123" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("RTN del negocio debe tener 14 dígitos")
    expect(SiteSetting.sole.rtn).to eq("08011999123456")

    patch administration_site_setting_path, params: { site_setting: { business_name: "Rey David", rtn: "" } }
    expect(SiteSetting.sole.rtn).to be_nil
    get trading_invoice_path(invoice)
    expect(response.body).not_to include("data-business-rtn")
  end

  it "takes a logo, shows it in the navigation bar and serves it to anyone, cached by version" do
    sign_in admin
    patch administration_site_setting_path, params: { site_setting: { business_name: "Rey David", logo: logo("logo.png", "image/png") } }
    setting = SiteSetting.sole
    expect(setting).to have_attributes(logo_content_type: "image/png", logo_filename: "logo.png", logo?: true)

    get root_path
    src = Nokogiri::HTML(response.body).at_css("header nav a img")["src"]
    expect(src).to eq(site_logo_path(v: setting.logo_version))

    delete session_path
    get src
    expect(response.media_type).to eq("image/png")
    expect(response.body.b).to eq(File.binread(file_fixture("logo.png")))
    expect(response.headers["Cache-Control"]).to include("public", "max-age=#{1.year.to_i}")

    event = AuditEvent.where(auditable_type: "SiteSetting").last
    expect(event.changeset.keys).to include("logo_filename", "business_name")
    expect(event.changeset.keys).not_to include("logo_data")
  end

  it "refuses files that are not images by their content, SVG included, and removes the logo" do
    sign_in admin
    patch administration_site_setting_path, params: { site_setting: { business_name: "Rey David", logo: logo("logo.svg", "image/png") } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("debe ser una imagen PNG, JPG, WebP o GIF")
    expect(SiteSetting.count).to eq(0)

    patch administration_site_setting_path, params: { site_setting: { business_name: "Rey David", logo: logo("logo.png", "image/png") } }
    patch administration_site_setting_path, params: { site_setting: { business_name: "Rey David", remove_logo: "1" } }
    expect(SiteSetting.sole.logo?).to be(false)
    get site_logo_path
    expect(response).to have_http_status(:not_found)
  end

  it "is for admins only" do
    user = create(:user)
    create(:permission, user:, module_key: "administration", can_read: true, can_create: true, can_update: true, can_destroy: true)
    sign_in user

    get administration_site_setting_path
    expect(response).to redirect_to(root_path)
    patch administration_site_setting_path, params: { site_setting: { business_name: "Otro" } }
    expect(SiteSetting.count).to eq(0)
  end
end
