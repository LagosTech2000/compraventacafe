require "rails_helper"

# Administración → Centro de control (Fernando, 2026-11-15): only the user
# who exports the data; the developments quoted apart with their hours,
# usefulness and suggested value, turned on there; the hourly rate; and the
# data maintenance tasks as its other tab.
RSpec.describe "Control center" do
  let(:exporter) { make_data_exporter(create(:user, :admin)) }
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)

  it "is only for the data exporter" do
    sign_in admin
    get administration_control_center_path
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")
    get administration_root_path
    expect(response.body).not_to include(administration_control_center_path)
  end

  it "lists the developments with their value, sets the rate and turns one on for the administrators" do
    sign_in exporter
    get administration_control_center_path
    cards = page.css("[data-paid-features] article")
    expect(cards.map { it.at_css("h2").text }).to eq([ "Huella de las personas", "Préstamos de los dueños" ])
    expect(cards.last.text).to include("14 horas", "Media", "L 1,400.00", "Apagado", "Préstamos de los dueños")
    expect(response.body).to include("Mantenimiento de datos")

    patch administration_control_setting_path, params: { control_setting: { hourly_rate: "150" } }
    expect(ControlSetting.current.hourly_rate).to eq(150)

    loans = PaidFeature.find_by!(key: "owner_loans")
    sign_in admin
    get finance_owner_loans_path
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")

    sign_in exporter
    patch administration_paid_feature_path(loans), params: { paid_feature: { enabled: "1", agreed_price: "1500", notes: "Aprobado" } }
    expect(loans.reload).to have_attributes(enabled: true, agreed_price: 1_500, enabled_by: exporter)
    expect(AuditEvent.where(auditable: loans).last.changeset).to include("enabled" => [ false, true ])

    sign_in admin
    get finance_owner_loans_path
    expect(response).to have_http_status(:ok)
  end

  it "is also in Configuración del sitio, only for the data exporter" do
    sign_in admin
    get administration_site_setting_path
    expect(Nokogiri::HTML(response.body).at_css("[data-site-paid-features]")).to be_nil

    sign_in exporter
    get administration_site_setting_path
    section = Nokogiri::HTML(response.body).at_css("[data-site-paid-features]")
    expect(section.text).to include("Acceso a los desarrollos cotizados aparte", "Préstamos de los dueños", "Valor por hora")
    loans = PaidFeature.find_by!(key: "owner_loans")
    patch administration_paid_feature_path(loans), params: { paid_feature: { enabled: "1" } }, headers: { "HTTP_REFERER" => administration_site_setting_url }
    expect(response).to redirect_to(administration_site_setting_url)
    expect(loans.reload).to be_enabled
  end
end
