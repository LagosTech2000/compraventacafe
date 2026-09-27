class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  skip_after_action :verify_authorized
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: t("sessions.rate_limited") }

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))

    if user&.active?
      start_new_session_for user
      AuditEvent.record!(action: "sign_in", auditable: user)
      redirect_to after_authentication_url
    else
      AuditEvent.record!(action: "sign_in_failed", label: params[:email_address].to_s.strip.first(254), user: nil)
      redirect_to new_session_path, alert: t("sessions.invalid")
    end
  end

  def destroy
    AuditEvent.record!(action: "sign_out", auditable: Current.user)
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
