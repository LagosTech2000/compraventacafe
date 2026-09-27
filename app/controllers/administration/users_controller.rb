module Administration
  class UsersController < ApplicationController
    before_action :set_user, only: %i[ show edit update edit_password reset_password ]

    def index
      authorize User
      @filter = UserFilter.new(params)
      @users, @next_page = @filter.results(policy_scope(User))
    end

    def show
      @user.build_missing_permissions
    end

    def new
      @user = authorize User.new
      @user.build_missing_permissions
    end

    def create
      @user = authorize User.new(create_params)

      if @user.save
        close_modal_with notice: t(".success"), fallback: administration_users_path
      else
        @user.build_missing_permissions
        render :new, status: :unprocessable_content
      end
    end

    def edit
      @user.build_missing_permissions
    end

    def update
      if @user.update(update_params)
        @user.sessions.destroy_all unless @user.active?
        close_modal_with notice: t(".success"), fallback: administration_users_path
      else
        @user.build_missing_permissions
        render :edit, status: :unprocessable_content
      end
    end

    def edit_password
    end

    def reset_password
      # has_secure_password silently ignores a blank password on update.
      if password_params[:password].blank?
        @user.errors.add(:password, :blank)
        render :edit_password, status: :unprocessable_content
      elsif @user.update(password_params)
        @user.sessions.destroy_all
        close_modal_with notice: t(".success"), fallback: administration_users_path
      else
        render :edit_password, status: :unprocessable_content
      end
    end

    private
      def set_user
        @user = authorize User.find(params[:id])
      end

      def permissions_attributes
        { permissions_attributes: [ [ :id, :module_key, :can_read, :can_create, :can_update, :can_destroy ] ] }
      end

      def create_params
        params.expect(user: [ :name, :email_address, :password, :password_confirmation, :admin, permissions_attributes ])
      end

      def update_params
        params.expect(user: [ :name, :email_address, :admin, :active, permissions_attributes ])
      end

      def password_params
        params.expect(user: [ :password, :password_confirmation ])
      end
  end
end
