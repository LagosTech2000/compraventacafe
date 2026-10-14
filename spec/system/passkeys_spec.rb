require "rails_helper"

# Fingerprint sign-in end to end (Fernando, 2026-10-13): Chrome's virtual
# authenticator plays a device with a fingerprint reader. WebAuthn wants a
# domain, not an IP: the app is visited at localhost.
RSpec.describe "Passkeys", type: :system do
  let(:user) { create(:user, name: "Ana Zelaya") }

  around do |example|
    app_host, include_port = Capybara.app_host, Capybara.always_include_port
    Capybara.app_host, Capybara.always_include_port = "http://localhost", true
    example.run
  ensure
    Capybara.app_host, Capybara.always_include_port = app_host, include_port
  end

  def add_fingerprint_reader
    browser_page = page.driver.browser.page
    browser_page.command("WebAuthn.enable")
    browser_page.command("WebAuthn.addVirtualAuthenticator", options: {
      protocol: "ctap2", transport: "internal", hasResidentKey: true, hasUserVerification: true, isUserVerified: true
    })
  end

  it "registers the fingerprint in Mi configuración and signs in with it, without typing" do
    visit new_session_path # the browser is on the site before adding the device
    add_fingerprint_reader
    sign_in_as(user)
    click_link "Ana Zelaya"

    within("dialog[open]") do
      expect(page).to have_text("Todavía no registras ninguna huella")
      fill_in "Nombre del dispositivo", with: "Laptop de la oficina"
      click_button "Registrar huella de este dispositivo"
      expect(page).to have_text("Laptop de la oficina")
      expect(page).to have_text("sin usar todavía")
    end
    expect(user.webauthn_credentials.sole.nickname).to eq("Laptop de la oficina")

    find("dialog[open]").send_keys(:escape)
    expect(page).to have_no_css("dialog[open]")
    click_button "Cerrar sesión"
    expect(page).to have_current_path(new_session_path)
    click_button "Entrar con huella"
    expect(page).to have_css("h1", text: "Hola, Ana Zelaya")
    expect(user.webauthn_credentials.sole.last_used_at).to be_present
  end

  it "says so when the device has no fingerprint registered here" do
    visit new_session_path
    add_fingerprint_reader
    click_button "Entrar con huella"
    # The virtual device has no key for this site: the browser refuses, and
    # nothing else happens (the person can still use the password).
    expect(page).to have_current_path(new_session_path)
    expect(page).to have_field("email_address")
  end
end
