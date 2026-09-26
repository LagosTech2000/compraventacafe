require "rails_helper"

# Only an admin creates users. There is no public sign-up, and password
# recovery by email is not routed.
RSpec.describe "No public registration" do
  it "exposes no unauthenticated route that creates users" do
    user_creating_routes = Rails.application.routes.routes.select do |route|
      route.verb.include?("POST") && route.defaults[:controller].to_s.match?(/user|registration|sign_?up/)
    end
    expect(user_creating_routes.map { |r| r.defaults[:controller] }.uniq).to eq([ "administration/users" ])
  end

  it "requires an admin to create a user" do
    expect {
      post administration_users_path, params: { user: { email_address: "x@example.com", password: "p", password_confirmation: "p" } }
    }.not_to change(User, :count)
    expect(response).to redirect_to(new_session_path)
  end

  it "does not route the email password recovery flow" do
    expect(Rails.application.routes.recognize_path("/passwords/new")).not_to include(controller: "passwords")
  rescue ActionController::RoutingError
    # Not routed at all: the expected outcome.
  end

  it "does not route common sign-up paths" do
    %w[/users/new /users/sign_up /registrations/new /signup /registro].each do |path|
      expect { Rails.application.routes.recognize_path(path) }.to raise_error(ActionController::RoutingError), path
    end
  end
end
