# Signing in with a passkey (fingerprint), from the sign-in page: one more
# way in, the password keeps working (Fernando, 2026-10-13). The device
# picks the user's key (discoverable credentials): no email is typed.
class PasskeySessionsController < ApplicationController
  CHALLENGE = :webauthn_authentication_challenge

  allow_unauthenticated_access
  skip_after_action :verify_authorized
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    RateLimitAudit.record(request, rule: "sign_in", period: 3.minutes)
    render json: { error: t("sessions.rate_limited") }, status: :too_many_requests
  }

  def options
    options = Passkeys.relying_party(request).options_for_authentication(user_verification: "required")
    session[CHALLENGE] = options.challenge
    render json: options
  end

  def create
    payload = JSON.parse(request.raw_post)
    verified, stored = Passkeys.relying_party(request).verify_authentication(payload["credential"], session.delete(CHALLENGE), user_verification: true) do |credential|
      WebauthnCredential.find_by(external_id: credential.id) || raise(WebAuthn::Error)
    end
    raise WebAuthn::Error unless stored.user.active?

    stored.update!(sign_count: verified.sign_count, last_used_at: Time.current)
    start_new_session_for stored.user
    AuditEvent.record!(action: "sign_in", auditable: stored.user, details: { method: "passkey", passkey: stored.nickname })
    render json: { redirect: after_authentication_url }
  rescue WebAuthn::Error, JSON::ParserError
    AuditEvent.record!(action: "sign_in_failed", label: t(".audit_label"), user: nil, details: { method: "passkey" })
    render json: { error: t(".failed") }, status: :unprocessable_content
  end
end
