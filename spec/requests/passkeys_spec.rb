require "rails_helper"
require "webauthn/fake_client"

# Signing in with a fingerprint (passkeys, WebAuthn; Fernando, 2026-10-13):
# each user registers their devices from Mi configuración, and the sign-in
# page takes them as one more way in. A fake device plays the browser.
RSpec.describe "Passkeys" do
  let(:user) { create(:user, name: "Ana Zelaya") }
  let(:device) { WebAuthn::FakeClient.new("http://www.example.com") }

  def json = response.parsed_body
  def post_json(path, body = {}) = post(path, params: body.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json" })

  def register(nickname: "Celular de Ana")
    post_json options_webauthn_credentials_path
    credential = device.create(challenge: json["challenge"], user_verified: true)
    post_json webauthn_credentials_path, credential:, nickname:
  end

  def sign_in_with_device(verified: true)
    post_json options_passkey_session_path
    post_json passkey_session_path, credential: device.get(challenge: json["challenge"], user_verified: verified)
  end

  it "registers this device's fingerprint for the signed-in user, audited" do
    sign_in user
    post_json options_webauthn_credentials_path
    expect(json).to include("rp" => a_hash_including("id" => "www.example.com"),
                            "user" => a_hash_including("name" => user.email_address, "displayName" => "Ana Zelaya"),
                            "authenticatorSelection" => a_hash_including("residentKey" => "required", "userVerification" => "required"))

    credential = device.create(challenge: json["challenge"], user_verified: true)
    post_json webauthn_credentials_path, credential:, nickname: "Celular de Ana"
    expect(response).to have_http_status(:ok)
    passkey = user.webauthn_credentials.sole
    expect(passkey).to have_attributes(nickname: "Celular de Ana", external_id: credential["id"])
    expect(AuditEvent.find_by(auditable: passkey, action: "create").auditable_label).to eq("Huella «Celular de Ana» de Ana Zelaya")

    get edit_user_setting_path
    expect(Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(passkey)}").text).to include("Celular de Ana", "sin usar todavía")
  end

  it "does not register a key made for another challenge or without the fingerprint" do
    sign_in user
    post_json options_webauthn_credentials_path
    post_json webauthn_credentials_path, credential: device.create(challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true)
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["error"]).to eq("No se pudo registrar la huella. Intenta de nuevo.")

    post_json options_webauthn_credentials_path
    post_json webauthn_credentials_path, credential: device.create(challenge: json["challenge"], user_verified: false)
    expect(response).to have_http_status(:unprocessable_content)
    expect(WebauthnCredential.count).to eq(0)
  end

  it "signs in with the fingerprint, without email nor password, audited" do
    sign_in user
    register
    delete session_path

    sign_in_with_device
    expect(response).to have_http_status(:ok)
    expect(json["redirect"]).to eq(root_url)
    expect(user.webauthn_credentials.sole.last_used_at).to be_present
    expect(AuditEvent.where(action: "sign_in", auditable: user).last.details).to include("method" => "passkey", "passkey" => "Celular de Ana")

    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "keeps the password working" do
    sign_in user
    register
    delete session_path

    sign_in user
    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "refuses an unknown key, a key without the fingerprint and an inactive user" do
    device.create(challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true)
    sign_in_with_device # a key the device has, never registered here
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["error"]).to include("No se pudo entrar con la huella")
    expect(AuditEvent.where(action: "sign_in_failed").last.details).to include("method" => "passkey")

    sign_in user
    register
    delete session_path
    sign_in_with_device(verified: false)
    expect(response).to have_http_status(:unprocessable_content)

    user.update_columns(active: false)
    sign_in_with_device
    expect(response).to have_http_status(:unprocessable_content)
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "lets each user remove their own fingerprints only" do
    sign_in user
    register
    passkey = user.webauthn_credentials.sole
    other = create(:user)
    delete session_path

    sign_in other
    delete webauthn_credential_path(passkey)
    expect(passkey.reload).to be_persisted

    sign_in user
    delete webauthn_credential_path(passkey)
    expect(response).to redirect_to(edit_user_setting_path)
    expect(WebauthnCredential.count).to eq(0)
    expect(AuditEvent.where(auditable_type: "WebauthnCredential", action: "destroy")).to exist
  end

  it "offers it on the sign-in page" do
    get new_session_path
    button = Nokogiri::HTML(response.body).at_css("[data-controller=passkey] button")
    expect(button.text.squish).to eq("Entrar con huella")
  end
end
