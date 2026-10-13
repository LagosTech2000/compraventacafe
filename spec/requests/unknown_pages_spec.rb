require "rails_helper"

RSpec.describe "Unknown pages and the sign-in page" do
  let(:user) { create(:user) }

  it "sends a signed-in user from the sign-in page to the home page" do
    sign_in user
    get new_session_path
    expect(response).to redirect_to(root_path)

    post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }
    expect(response).to redirect_to(root_path)
    expect(AuditEvent.where(action: "sign_in").count).to eq(1) # only the first one
  end

  it "still shows the sign-in page to visitors" do
    get new_session_path
    expect(response).to have_http_status(:ok)
  end

  it "answers an unknown address with a Spanish alert, back home, and audits it" do
    sign_in user
    get "/test"
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq("La página que buscas no existe. Revisa la dirección o usa el menú.")

    event = AuditEvent.where(action: "error").sole
    expect(event).to have_attributes(user:, auditable_label: "404 GET /test")
    expect(event.details).to include("status" => 404, "error" => "ActionController::RoutingError", "controller" => "errors#not_found")

    post "/no/existe/tampoco.json"
    expect(response).to have_http_status(:not_found)
  end

  it "asks a visitor to sign in first, like any other page" do
    get "/test"
    expect(response).to redirect_to(new_session_path)
  end

  it "leaves the real routes and Rails' own alone" do
    get "/up"
    expect(response).to have_http_status(:ok)
    expect(Rails.application.routes.recognize_path("/recede_historical_location")).to include(controller: "turbo/native/navigation")
  end
end
