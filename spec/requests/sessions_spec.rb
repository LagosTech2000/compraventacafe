require "rails_helper"

RSpec.describe "Sessions" do
  let(:user) { create(:user) }

  it "shows the sign-in form in Spanish" do
    get new_session_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("sessions.new.title"))
  end

  it "signs in an active user" do
    sign_in user
    expect(response).to redirect_to(root_url)
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it "rejects a wrong password" do
    post session_path, params: { email_address: user.email_address, password: "wrong" }
    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq(I18n.t("sessions.invalid"))
  end

  it "rejects an inactive user with the same message" do
    inactive = create(:user, :inactive)
    sign_in inactive
    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq(I18n.t("sessions.invalid"))
    expect(inactive.sessions).to be_empty
  end

  it "ends an open session once the user is deactivated" do
    sign_in user
    user.update!(active: false)
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "requires authentication for the app" do
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "signs out" do
    sign_in user
    delete session_path
    expect(response).to redirect_to(new_session_path)
    get root_path
    expect(response).to redirect_to(new_session_path)
  end
end
