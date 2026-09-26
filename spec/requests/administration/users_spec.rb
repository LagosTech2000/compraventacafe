require "rails_helper"

RSpec.describe "Administration::Users" do
  let!(:admin) { create(:user, :admin) }

  context "as a non-admin, even with every administration flag" do
    before do
      user = create(:user)
      create(:permission, user: user, module_key: "administration", can_read: true, can_create: true, can_update: true, can_destroy: true)
      sign_in user
    end

    it "cannot list users" do
      get administration_users_path
      expect(response).to redirect_to(root_path)
    end

    it "cannot create users" do
      expect {
        post administration_users_path, params: { user: { email_address: "x@example.com", password: "p", password_confirmation: "p" } }
      }.not_to change(User, :count)
    end
  end

  context "as an admin" do
    before { sign_in admin }

    it "lists users" do
      get administration_users_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin.email_address)
    end

    it "shows a permission row for every module on the new form" do
      get new_administration_user_path
      AppModule::KEYS.each { |key| expect(response.body).to include(CGI.escapeHTML(AppModule.human_name(key))) }
    end

    it "creates a user with per-module permissions" do
      post administration_users_path, params: {
        user: {
          email_address: "nueva@example.com", password: "clave-larga", password_confirmation: "clave-larga", admin: "0",
          permissions_attributes: {
            "0" => { module_key: "trading", can_read: "1", can_create: "1", can_update: "0", can_destroy: "0" },
            "1" => { module_key: "farms", can_read: "0", can_create: "0", can_update: "0", can_destroy: "0" }
          }
        }
      }
      expect(response).to redirect_to(administration_users_path)
      user = User.find_by!(email_address: "nueva@example.com")
      expect(user.can?(:trading, :create)).to be(true)
      expect(user.can?(:trading, :update)).to be(false)
      expect(user.can?(:farms, :read)).to be(false)
    end

    it "updates an existing user's permissions" do
      user = create(:user)
      permission = create(:permission, user: user, module_key: "loans", can_read: true)
      patch administration_user_path(user), params: {
        user: { permissions_attributes: { "0" => { id: permission.id, module_key: "loans", can_read: "0", can_update: "1" } } }
      }
      expect(response).to redirect_to(administration_users_path)
      expect(user.reload.can?(:loans, :read)).to be(false)
      expect(user.can?(:loans, :update)).to be(true)
    end

    it "shows the edit form with the permission matrix" do
      get edit_administration_user_path(create(:user))
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("can_destroy")
    end

    it "deactivates a user and ends their sessions" do
      user = create(:user)
      user.sessions.create!
      patch administration_user_path(user), params: { user: { active: "0" } }
      expect(user.reload.active?).to be(false)
      expect(user.sessions).to be_empty
    end

    it "refuses to deactivate the last active admin, in Spanish" do
      patch administration_user_path(admin), params: { user: { active: "0" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(CGI.escapeHTML(I18n.t("activerecord.errors.models.user.last_active_admin")))
      expect(admin.reload.active?).to be(true)
    end

    it "refuses to remove admin from the last active admin" do
      patch administration_user_path(admin), params: { user: { admin: "0" } }
      expect(admin.reload.admin?).to be(true)
    end

    it "resets a password and ends the user's sessions" do
      user = create(:user)
      user.sessions.create!
      patch reset_password_administration_user_path(user), params: { user: { password: "otra-clave", password_confirmation: "otra-clave" } }
      expect(response).to redirect_to(administration_users_path)
      expect(user.reload.authenticate("otra-clave")).to be_truthy
      expect(user.sessions).to be_empty
    end

    it "rejects a blank password reset" do
      user = create(:user)
      patch reset_password_administration_user_path(user), params: { user: { password: "", password_confirmation: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate(AuthenticationHelpers::PASSWORD)).to be_truthy
    end

    it "rejects a mismatched confirmation" do
      user = create(:user)
      patch reset_password_administration_user_path(user), params: { user: { password: "una-clave", password_confirmation: "otra" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "has no way to delete users" do
      expect { Rails.application.routes.recognize_path(administration_user_path(admin), method: :delete) }
        .to raise_error(ActionController::RoutingError)
    end
  end
end
