# Registers and removes the signed-in user's passkeys (WebauthnCredential),
# from Mi configuración. passkey_controller.js asks for the options, lets the
# device create the key (fingerprint) and sends it back here.
class WebauthnCredentialsController < ApplicationController
  CHALLENGE = :webauthn_registration_challenge

  # The options for the device: a fresh challenge, the user and the keys
  # it already has (a device is not registered twice).
  def options
    authorize WebauthnCredential.new(user: Current.user), :create?
    user = Current.user
    user.update!(webauthn_id: WebAuthn.generate_user_id) unless user.webauthn_id
    options = Passkeys.relying_party(request).options_for_registration(
      user: { id: user.webauthn_id, name: user.email_address, display_name: user.name },
      exclude: user.webauthn_credentials.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "required" }
    )
    session[CHALLENGE] = options.challenge
    render json: options
  end

  def create
    credential = authorize Current.user.webauthn_credentials.build
    payload = JSON.parse(request.raw_post)
    verified = Passkeys.relying_party(request).verify_registration(payload["credential"], session.delete(CHALLENGE), user_verification: true)
    credential.assign_attributes(external_id: verified.id, public_key: verified.public_key, sign_count: verified.sign_count,
                                 nickname: payload["nickname"].to_s.presence || t(".default_nickname"))
    if credential.save
      flash[:notice] = t(".success")
      render json: { ok: true }
    else
      render json: { error: credential.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  rescue WebAuthn::Error, JSON::ParserError
    render json: { error: t(".failed") }, status: :unprocessable_content
  end

  def destroy
    credential = authorize Current.user.webauthn_credentials.find(params[:id])
    credential.destroy!
    redirect_to edit_user_setting_path, notice: t(".success"), status: :see_other
  end
end
