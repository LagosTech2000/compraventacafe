module Finance
  # Roles of the Planilla interna: salary per period, pay frequency and
  # overtime hour rate.
  class StaffRolesController < ApplicationController
    before_action :set_role, only: %i[ edit update destroy ]

    def index
      authorize StaffRole
      @filter = StaffRoleFilter.new(params)
      @roles, @next_page = @filter.results(policy_scope(StaffRole))
    end

    def new
      @role = authorize StaffRole.new(pay_frequency: "biweekly")
    end

    def create
      @role = authorize StaffRole.new(role_params)

      if @role.save
        close_modal_with notice: t(".success"), fallback: finance_staff_roles_path,
                         event: "staff-role:created", detail: { id: @role.id, name: @role.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @role.update(role_params)
        close_modal_with notice: t(".success"), fallback: finance_staff_roles_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @role.destroy!
      close_modal_with notice: t(".success"), fallback: finance_staff_roles_path
    end

    private
      def set_role
        @role = authorize StaffRole.find(params[:id])
      end

      def role_params
        params.expect(staff_role: [ :name, :salary, :pay_frequency, :overtime_hour_rate, :active ])
      end
  end
end
