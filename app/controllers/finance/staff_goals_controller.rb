module Finance
  # A goal of an employee for a period, with its bonus: marked met (or not)
  # when the period is paid.
  class StaffGoalsController < ApplicationController
    before_action :set_member

    def new
      @goal = authorize @member.goals.build(period_starts_on: @member.goal_periods.first&.starts_on)
    end

    def create
      @goal = authorize @member.goals.build(goal_params.merge(created_by: Current.user))

      if @goal.save
        close_modal_with notice: t(".success"), fallback: finance_staff_member_path(@member, tab: "goals")
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      goal = authorize @member.goals.find(params[:id])
      goal.destroy!
      close_modal_with notice: t(".success"), fallback: finance_staff_member_path(@member, tab: "goals")
    end

    private
      def set_member
        @member = StaffMember.includes(:person, :role, :payments).find(params[:staff_member_id])
      end

      def goal_params
        params.expect(staff_goal: [ :period_starts_on, :description, :bonus_amount ])
      end
  end
end
