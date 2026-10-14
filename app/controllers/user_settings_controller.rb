# The signed-in user's own settings (Fernando, 2026-10-13), opened from their
# name in the navigation: their name, email, photo and password, how pages
# open (modal or drawer), where the navigation sits, and the fingerprints
# they sign in with (WebauthnCredentialsController). Changing the email or
# the password asks for the current password.
class UserSettingsController < ApplicationController
  before_action :set_user

  def edit
  end

  def update
    @user.assign_attributes(user_setting_params.except(:current_password))
    # has_secure_password checks it against the saved password.
    @user.password_challenge = user_setting_params[:current_password].to_s if credentials_change?

    if @user.save
      close_modal_with notice: t(".success"), fallback: root_path
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_user
      @user = authorize Current.user, policy_class: UserSettingPolicy
    end

    def user_setting_params
      params.expect(user: [ :name, :email_address, :photo_upload, :remove_photo, :current_password, :password, :password_confirmation,
                            :window_style, :nav_position ])
    end

    def credentials_change?
      @user.email_address_changed? || @user.password.present?
    end
end
