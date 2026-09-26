require "rails_helper"

# Every form carries the browser-side version of its model's validations.
RSpec.describe "Form validations" do
  def field(css)
    Nokogiri::HTML(response.body).at_css(css)
  end

  it "validates the sign-in form without revealing password rules" do
    get new_session_path
    expect(field("form")["data-controller"]).to eq("form-validation")
    expect(field("#email_address")["type"]).to eq("email")
    expect(field("#email_address")["required"]).to be_present
    expect(field("#password")["data-missing-message"]).to eq("Contraseña no puede estar en blanco")
    expect(field("#password")["minlength"]).to be_nil
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "validates the new-user form" do
      get new_administration_user_path
      expect(field("#user_email_address")["data-invalid-message"]).to eq("Correo electrónico no es un correo válido")
      expect(field("#user_password")["minlength"]).to eq("8")
      expect(field("#user_password")["data-invalid-message"]).to eq("Contraseña debe tener al menos 8 caracteres")
      expect(field("#user_password_confirmation")["data-must-match"]).to eq("user_password")
      expect(field("#user_password_confirmation")["data-mismatch-message"]).to eq("Confirmar contraseña no coincide con Contraseña")
    end

    it "validates the reset-password form" do
      get reset_password_administration_user_path(create(:user))
      expect(field("form[action$='reset_password']")["data-controller"]).to eq("form-validation")
      expect(field("#user_password")["minlength"]).to eq("8")
    end

    it "rejects a short password on the server too" do
      post administration_users_path, params: { user: { email_address: "corta@example.com", password: "corta", password_confirmation: "corta" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Contraseña debe tener al menos 8 caracteres")
    end
  end

  it "keeps existing short passwords working at sign-in" do
    user = create(:user)
    user.update_columns(password_digest: BCrypt::Password.create("corta"))
    post session_path, params: { email_address: user.email_address, password: "corta" }
    expect(response).to redirect_to(root_url)
  end
end
