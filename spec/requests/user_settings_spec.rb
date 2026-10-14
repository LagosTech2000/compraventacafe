require "rails_helper"

# Each user's own display settings (UserSettingsController): modal or drawer
# for the pages that open over the page, navigation at the top or the left.
RSpec.describe "User settings" do
  let(:user) { create(:user) }

  def page = Nokogiri::HTML(response.body)

  before { sign_in user }

  it "opens from the user's name in the navigation, in the modal" do
    get root_path
    link = page.at_css("header nav a[href='#{edit_user_setting_path}']")
    expect(link["data-turbo-frame"]).to eq("modal")
    expect(link.text).to include(user.name)

    get edit_user_setting_path, headers: { "Turbo-Frame" => "modal" }
    expect(response).to have_http_status(:ok)
    expect(page.css("input[type=radio]").map { it["value"] }).to eq(%w[modal drawer top left])
    expect(page.at_css("input[value=modal]")["checked"]).to be_present
  end

  it "saves the user's choices and the pages follow them" do
    patch user_setting_path, params: { user: { window_style: "drawer", nav_position: "left" } }

    expect(response).to redirect_to(root_path)
    expect(user.reload).to have_attributes(window_style: "drawer", nav_position: "left")
    expect(AuditEvent.where(auditable: user, action: "update")).to exist

    follow_redirect!
    expect(page.css("dialog.modal.drawer").size).to eq(ModalSupport::MODAL_FRAMES.size)
    expect(page.at_css("aside nav a[href='#{edit_user_setting_path}']")).to be_present
    expect(page.at_css("header")["class"]).to include("lg:hidden")
  end

  it "draws the left navigation collapsed when the browser says so, only for that setting" do
    user.update!(nav_position: "left")
    cookies[SidebarState::COOKIE] = "1"
    get root_path
    expect(page.at_css("body")["class"]).to include("sidebar-collapsed")
    expect(page.at_css("aside button[aria-expanded=false]")["aria-label"]).to eq("Mostrar el menú completo")

    user.update!(nav_position: "top")
    get root_path
    expect(page.at_css("body")["class"]).not_to include("sidebar-collapsed")
  end

  it "keeps the centered modal and the top bar by default" do
    get root_path

    expect(page.css("dialog.drawer")).to be_empty
    expect(page.at_css("aside nav")).to be_nil
  end

  it "rejects values it does not know" do
    patch user_setting_path, params: { user: { window_style: "popup", nav_position: "bottom" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload).to have_attributes(window_style: "modal", nav_position: "top")
  end

  it "changes only the user's own data and settings, never their permissions" do
    patch user_setting_path, params: { user: { window_style: "drawer", admin: true, active: false, name: "Otro Nombre" } }

    expect(user.reload).to have_attributes(window_style: "drawer", admin: false, active: true, name: "Otro Nombre")
  end

  describe "the user's own data (Fernando, 2026-10-13)" do
    let(:password) { AuthenticationHelpers::PASSWORD }

    it "is a full form: data, photo, display, password and fingerprints" do
      get edit_user_setting_path
      expect(page.at_css("input[name='user[name]']")["value"]).to eq(user.name)
      expect(page.at_css("input[name='user[email_address]']")["value"]).to eq(user.email_address)
      expect(page.at_css("input[type=file][name='user[photo_upload]']")).to be_present
      expect(page.css("input[type=password]").map { it["name"] }).to eq(%w[user[current_password] user[password] user[password_confirmation]])
      expect(page.at_css("[data-controller=passkey]").text).to include("Huella digital", "Todavía no registras ninguna huella")
    end

    it "changes the name and the photo without the password" do
      patch user_setting_path, params: { user: { name: "Ana María Zelaya", photo_upload: uploaded_picture } }

      expect(user.reload).to have_attributes(name: "Ana María Zelaya")
      expect(user.photo).to be_present
      get root_path
      expect(page.at_css("header nav a[href='#{edit_user_setting_path}'] img")["src"]).to eq(profile_photo_path(user.photo, v: user.photo.version))
    end

    it "asks the current password to change the email or the password" do
      patch user_setting_path, params: { user: { email_address: "nuevo@example.com", current_password: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Contraseña actual no es la que tienes ahora")
      expect(user.reload.email_address).not_to eq("nuevo@example.com")

      patch user_setting_path, params: { user: { password: "otra-clave-123", password_confirmation: "otra-clave-123", current_password: "equivocada" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate(password)).to be_truthy

      patch user_setting_path, params: { user: { email_address: "nuevo@example.com", password: "otra-clave-123",
                                                 password_confirmation: "otra-clave-123", current_password: password } }
      expect(response).to redirect_to(root_path)
      expect(user.reload.email_address).to eq("nuevo@example.com")
      expect(user.authenticate("otra-clave-123")).to be_truthy
      expect(AuditEvent.where(auditable: user, action: "update").last.changeset["password_digest"]).to eq([ AuditEvent::FILTERED, AuditEvent::FILTERED ])
    end

    it "refuses a new password that does not match its confirmation" do
      patch user_setting_path, params: { user: { password: "otra-clave-123", password_confirmation: "otra-cosa-123", current_password: password } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate(password)).to be_truthy
    end

    it "keeps the password when the fields are left blank" do
      patch user_setting_path, params: { user: { name: "Ana", password: "", password_confirmation: "", current_password: "" } }

      expect(response).to redirect_to(root_path)
      expect(user.reload.authenticate(password)).to be_truthy
    end
  end

  describe "links inside a page in the drawer" do
    let(:user) { create(:user, :admin, window_style: "drawer") }

    it "navigate the drawer itself, and a picker still opens on top" do
      purchase = create(:purchase)
      InvoiceIssuer.new(producer: purchase.producer, user:, purchase_ids: [ purchase.id ], payment_status: "pending").call
      get trading_invoice_path(Invoice.last), headers: { "Turbo-Frame" => "modal" }
      expect(page.css("a[data-turbo-frame='modal_2']")).to be_empty
      expect(page.css("a[data-turbo-frame='modal']")).not_to be_empty

      get new_trading_purchase_path, headers: { "Turbo-Frame" => "modal" }
      expect(page.at_css("a[href='#{new_trading_zone_path(picker: 1)}']")["data-turbo-frame"]).to eq("modal_2")
    end
  end
end
