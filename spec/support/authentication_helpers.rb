module AuthenticationHelpers
  PASSWORD = "secret-password".freeze

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: PASSWORD }
  end
end
