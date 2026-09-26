require "rails_helper"

# An action that forgets to call its policy must fail.
RSpec.describe "verify_authorized", type: :request do
  let(:unauthorized_controller) do
    Class.new(ApplicationController) do
      def index
        head :ok
      end
    end
  end

  before do
    stub_const("ForgetfulController", unauthorized_controller)
    Rails.application.routes.draw do
      resource :session, only: %i[ new create ]
      root "dashboard#show"
      get "forgetful" => "forgetful#index"
    end
  end

  after { Rails.application.reload_routes! }

  it "raises when an action does not authorize" do
    sign_in create(:user)
    expect { get "/forgetful" }.to raise_error(Pundit::AuthorizationNotPerformedError)
  end
end
