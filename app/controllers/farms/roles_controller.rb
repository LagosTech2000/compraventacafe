module Farms
  # Roles of a daily payroll, each with its daily wage.
  class RolesController < ApplicationController
    include FarmsPayrollScoped
    before_action :set_role, only: %i[ edit update destroy ]

    def new
      @role = authorize @payroll.roles.build
    end

    def create
      @role = authorize @payroll.roles.build(role_params)

      if @role.save
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("members"),
                         event: "role:created", detail: { id: @role.id, name: @role.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @role.update(role_params)
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("members")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @role.destroy
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("members")
      else
        redirect_back_or_to payroll_tab_path("members"), alert: t(".in_use")
      end
    end

    private
      def set_role
        @role = authorize @payroll.roles.find(params[:id])
      end

      def role_params
        params.expect(payroll_role: [ :name, :daily_wage ])
      end
  end
end
