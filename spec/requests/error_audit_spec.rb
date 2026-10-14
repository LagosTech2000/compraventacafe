require "rails_helper"

# Every error a user runs into is in the audit log (ErrorAudit): who, which
# route, the status, the error and its reference code. Visitors without a
# session only leave server errors (bots probing addresses are not kept).
RSpec.describe "Audited errors" do
  let(:user) { create(:user, name: "Ana Zelaya").tap { |u| create(:permission, user: u, module_key: "administration", can_read: true) } }

  def error_event = AuditEvent.where(action: "error").sole

  # What ShowExceptions hands the exceptions app: the original path kept
  # aside, PATH_INFO set to the status page.
  def failed_env(path, exception, status)
    Rack::MockRequest.env_for(path, "action_dispatch.exception" => exception, "action_dispatch.original_path" => path,
                                    "action_dispatch.request_id" => SecureRandom.uuid, "HTTP_ACCEPT" => "text/html").merge("PATH_INFO" => "/#{status}")
  end

  it "keeps a missing record with the route, user, status and reference" do
    sign_in user
    get administration_person_path(id: 0, tab: "x")

    event = error_event
    expect(event).to have_attributes(user:, auditable_label: "404 GET /administration/people/0")
    expect(event.details).to include("status" => 404, "method" => "GET", "path" => "/administration/people/0?tab=x",
                                     "controller" => "administration/people#show", "error" => "ActiveRecord::RecordNotFound",
                                     "reference" => event.request_id.first(8))
  end

  it "keeps what the user was not allowed to do and an expired form" do
    sign_in user
    post administration_people_path, params: { person: { first_names: "Ana" } }
    expect(error_event.details).to include("status" => 403, "error" => "Pundit::NotAuthorizedError")
    expect(error_event.details["params"]).to include("Ana")
  end

  it "keeps an unexpected error with its message and where it failed, never showing it to the user" do
    Rails.configuration.x.friendly_errors = true
    allow_any_instance_of(Administration::PeopleController).to receive(:index).and_raise(RuntimeError, "boom en personas")
    sign_in user
    get administration_people_path

    expect(flash[:alert]).not_to include("boom")
    details = error_event.details
    expect(details).to include("status" => 500, "error" => "RuntimeError", "message" => "boom en personas")
    expect(details["backtrace"]).to be_present
  ensure
    Rails.configuration.x.friendly_errors = false
  end

  it "keeps a visitor's server errors but not their missing pages" do
    exceptions_app = Rails.application.config.exceptions_app
    status, _, body = exceptions_app.call(failed_env("/wp-admin", ActionController::RoutingError.new("No route"), 404))
    expect(status).to eq(404)
    expect(body.join).to include("lang=\"es\"")
    expect(AuditEvent.where(action: "error")).to be_empty

    exceptions_app.call(failed_env("/compras", RuntimeError.new("caída"), 500))
    expect(error_event).to have_attributes(user: nil, auditable_label: "500 GET /compras")
    expect(error_event.details).to include("error" => "RuntimeError", "message" => "caída")
  end

  it "keeps a signed-in user's unknown address, found from the session cookie" do
    allow(ErrorAudit).to receive(:user_from_cookie).and_return(user)
    Rails.application.config.exceptions_app.call(failed_env("/trading/no-existe", ActionController::RoutingError.new("No route"), 404))
    expect(error_event).to have_attributes(user:, auditable_label: "404 GET /trading/no-existe")
  end

  it "never breaks the response when the audit itself fails" do
    sign_in user
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::ConnectionNotEstablished)
    get administration_person_path(id: 0)
    expect(response).to redirect_to(root_path)
  end

  it "shows the error and its details in the audit screen" do
    admin = create(:user, :admin)
    sign_in user
    get administration_person_path(id: 0)
    delete session_path
    sign_in admin

    get administration_audit_event_path(error_event)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("#audit-sentence").text).to include("Ana Zelaya recibió un error 404 GET /administration/people/0")
    expect(page.text.squish).to include("Detalle del error", "Ruta /administration/people/0", "Error ActiveRecord::RecordNotFound")

    get administration_audit_events_path(action_type: "error")
    expect(response).to have_http_status(:ok)
  end

  it "names backups and invoice payments in the audit screen" do
    admin = make_data_exporter(create(:user, :admin))
    sign_in admin
    post administration_backup_path
    invoice = create(:invoice)
    invoice.payments.create!(amount: 100, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)

    get administration_audit_events_path
    expect(response.body).to include("descargó el respaldo", "el abono a factura")
  end

  it "answers an unknown address with a Spanish alert and audits it, as in production" do
    env_config = Rails.application.env_config
    original = env_config.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    env_config.merge!("action_dispatch.show_exceptions" => :all, "action_dispatch.show_detailed_exceptions" => false)
    sign_in user

    get "/trading/no-existe"
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to include("La página que buscas no existe")
    expect(error_event).to have_attributes(user:, auditable_label: "404 GET /trading/no-existe")
  ensure
    env_config.merge!(original)
  end
end
