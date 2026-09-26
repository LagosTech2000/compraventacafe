require "rails_helper"

RSpec.describe "Module access" do
  AppModule::KEYS.each do |key|
    describe key do
      let(:path) { Rails.application.routes.url_helpers.public_send("#{key}_root_path") }

      it "opens for a user who can read it" do
        user = create(:user)
        create(:permission, user: user, module_key: key, can_read: true)
        sign_in user
        get path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML(AppModule.human_name(key)))
      end

      it "redirects a user who cannot read it" do
        sign_in create(:user)
        get path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("authorization.forbidden"))
      end
    end
  end

  it "lists only readable modules on the home page" do
    user = create(:user)
    create(:permission, user: user, module_key: "farms", can_read: true)
    create(:permission, user: user, module_key: "loans", can_create: true)
    sign_in user
    get root_path
    expect(response.body).to include(farms_root_path)
    expect(response.body).not_to include(loans_root_path)
    expect(response.body).not_to include(trading_root_path)
  end
end
