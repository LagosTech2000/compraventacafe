module AuthenticationHelpers
  PASSWORD = "secret-password".freeze

  # Signs out first, like a person switching users: signed in, the sign-in
  # page sends you home (SessionsController#redirect_signed_in).
  def sign_in(user)
    delete session_path if cookies[:session_id].present?
    post session_path, params: { email_address: user.email_address, password: PASSWORD }
  end
end
