module Finance
  # The Planilla interna: its employees, what each period pays and, on each
  # one's page, their periods, payments, advances and goals.
  class StaffMembersController < ApplicationController
    before_action :set_member, only: %i[ show edit update destroy ]

    TABS = %w[periods payments advances goals].freeze

    def index
      authorize StaffMember
      @filter = StaffMemberFilter.new(params)
      @members, @next_page = @filter.results(policy_scope(StaffMember))
      @overview = StaffOverview.new
    end

    def show
      @tab = params[:tab].presence_in(TABS) || TABS.first
    end

    def new
      @member = authorize StaffMember.new(starts_on: Time.zone.today, person_id: params[:person_id])
    end

    def create
      @member = authorize StaffMember.new(member_params)

      if @member.save
        close_modal_with notice: t(".success"), fallback: finance_staff_member_path(@member)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @member.update(member_params.except(:person_id))
        close_modal_with notice: t(".success"), fallback: finance_staff_member_path(@member)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @member.destroy!
      close_modal_with notice: t(".success"), fallback: finance_staff_members_path
    end

    private
      def set_member
        @member = authorize StaffMember.includes(:role, { person: :photo_info }, payments: %i[money_account role], advances: :money_account, goals: [], attendances: []).find(params[:id])
      end

      def member_params
        params.expect(staff_member: [ :person_id, :staff_role_id, :salary_override, :starts_on, :ends_on, :active, :observations ])
      end
  end
end
