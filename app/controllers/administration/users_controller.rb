module Administration
  class UsersController < ApplicationController
    before_action :set_user, only: %i[ show edit update edit_password reset_password ]

    def index
      authorize User
      @users = User.order(active: :desc, email_address: :asc)
    end

    def show
      redirect_to edit_administration_user_path(@user)
    end

    def new
      @user = authorize User.new
      @user.build_missing_permissions
    end

    def create
      @user = authorize User.new(create_params)

      if @user.save
        redirect_to administration_users_path, notice: t(".success")
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
        redirect_to administration_users_path, notice: t(".success")
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
        redirect_to administration_users_path, notice: t(".success")
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
        params.expect(user: [ :email_address, :password, :password_confirmation, :admin, permissions_attributes ])
      end

      def update_params
        params.expect(user: [ :email_address, :admin, :active, permissions_attributes ])
      end

      def password_params
        params.expect(user: [ :password, :password_confirmation ])
      end
  end
end
