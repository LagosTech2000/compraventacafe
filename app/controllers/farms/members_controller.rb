module Farms
  # People working a payroll: collaborators, with a role and/or a wage of
  # their own in daily payrolls.
  class MembersController < ApplicationController
    include FarmsPayrollScoped
    before_action :set_member, only: %i[ edit update destroy ]

    def new
      @member = authorize @payroll.members.build(person: Person.collaborators.find_by(id: params[:person_id]))
    end

    def create
      @member = authorize @payroll.members.build(member_params)

      if @member.save
        close_modal_with notice: t(".success", person: @member.full_name), fallback: payroll_tab_path("members")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @member.update(member_params.except(:person_id))
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("members")
      else
        render :edit, status: :unprocessable_content
      end
    end

    # Only while nothing was recorded for them; otherwise they are deactivated.
    def destroy
      if @member.destroy
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("members")
      else
        redirect_back_or_to payroll_tab_path("members"), alert: t(".in_use")
      end
    end

    private
      def set_member
        @member = authorize @payroll.members.find(params[:id])
      end

      def member_params
        params.expect(payroll_member: [ :person_id, :payroll_role_id, :daily_wage_override, :active ])
      end
  end
end
