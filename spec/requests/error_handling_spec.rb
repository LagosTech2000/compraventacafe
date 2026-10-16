require "rails_helper"

RSpec.describe "Error handling" do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  around do |example|
    original = Rails.configuration.x.friendly_errors
    Rails.configuration.x.friendly_errors = true
    example.run
  ensure
    Rails.configuration.x.friendly_errors = original
  end

  describe "unexpected errors" do
    before do
      allow_any_instance_of(Administration::PeopleController).to receive(:index).and_raise(RuntimeError, "secret internals")
      allow_any_instance_of(Administration::PeopleController).to receive(:create).and_raise(RuntimeError, "secret internals")
    end

    it "renders a Spanish alert with a reference code on a page load" do
      get administration_people_path
      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("Ocurrió un error inesperado")
      expect(response.body).to match(/con el código [0-9a-f-]{8}/)
      expect(response.body).to include('role="alert"')
    end

    it "never shows the exception message or class" do
      get administration_people_path
      expect(response.body).not_to include("secret internals")
      expect(response.body).not_to include("RuntimeError")
    end

    it "sends a failed form back to its page with the alert" do
      post administration_people_path, params: { person: { first_names: "Ana", last_names: "Paz" } },
                                       headers: { "HTTP_REFERER" => new_administration_person_url }
      expect(response).to redirect_to(new_administration_person_url)
      expect(flash[:alert]).to include("Ocurrió un error inesperado")
    end

    it "reports the error with its reference" do
      expect(Rails.error).to receive(:report).with(an_instance_of(RuntimeError), hash_including(handled: true))
      get administration_people_path
    end

    it "does not redirect in a loop when the home page itself fails" do
      allow_any_instance_of(DashboardController).to receive(:show).and_raise(RuntimeError)
      get root_path
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  it "raises in development so the developer sees the trace" do
    Rails.configuration.x.friendly_errors = false
    allow_any_instance_of(Administration::PeopleController).to receive(:index).and_raise(RuntimeError, "boom")
    expect { get administration_people_path }.to raise_error(RuntimeError, "boom")
  end

  it "turns a missing record into an alert" do
    get administration_person_path(id: 0)
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq(I18n.t("errors.handled.not_found"))
  end

  it "turns a form without its fields into an alert" do
    post administration_people_path, params: {}, headers: { "HTTP_REFERER" => new_administration_person_url }
    expect(response).to redirect_to(new_administration_person_url)
    expect(flash[:alert]).to eq(I18n.t("errors.handled.bad_request"))
  end

  it "turns an expired form into an alert" do
    ActionController::Base.allow_forgery_protection = true
    post administration_people_path, params: { person: { first_names: "Ana", last_names: "Paz" }, authenticity_token: "stale" },
                                     headers: { "HTTP_REFERER" => new_administration_person_url }
    expect(response).to redirect_to(new_administration_person_url)
    expect(flash[:alert]).to eq(I18n.t("errors.handled.expired_form"))
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "answers 406, not a server error, to a page asked for in a format it does not have" do
    get administration_people_path, headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:not_acceptable)
    expect(AuditEvent.where(action: "error").sole.details).to include("status" => 406, "error" => "ActionController::UnknownFormat")
  end

  it "shows alerts as toasts the user closes, which do not go away by themselves" do
    get administration_person_path(id: 0)
    follow_redirect!
    toast = Nokogiri::HTML(response.body).at_css(".toast-region .toast-alert[role=alert]")
    expect(toast["data-toast-timeout-value"]).to eq("0")
    expect(toast.at_css("button[data-action='toast#dismiss']")).to be_present
  end
end

RSpec.describe "Error handling for visitors" do
  around do |example|
    original = Rails.configuration.x.friendly_errors
    Rails.configuration.x.friendly_errors = true
    example.run
  ensure
    Rails.configuration.x.friendly_errors = original
  end

  it "answers 406 to bots asking for the sign-in page as JSON or text, without filling the audit log" do
    [ "application/json", "text/plain" ].each do |accept|
      get new_session_path, headers: { "Accept" => accept }
      expect(response).to have_http_status(:not_acceptable), accept
    end
    expect(AuditEvent.where(action: "error")).to be_empty
  end
end

RSpec.describe "Static error pages" do
  %w[400 404 406-unsupported-browser 422 500].each do |page|
    it "#{page}.html is in Spanish" do
      html = Rails.public_path.join("#{page}.html").read
      expect(html).to include('lang="es"')
      expect(html).to include("Volver al inicio")
    end
  end
end
