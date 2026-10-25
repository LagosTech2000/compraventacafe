module Finance
  # An advance to an employee of the Planilla interna, taken off the payment
  # of its period. Registered in a modal from the employee's page.
  class StaffAdvancesController < ApplicationController
    before_action :set_member

    def new
      @advance = authorize @member.advances.build(given_on: Time.zone.today, payment_method: "cash",
                                                  money_account: MoneyAccount.default_for("cash"))
    end

    def create
      @advance = authorize @member.advances.build(advance_params.merge(created_by: Current.user))

      if @advance.save
        close_modal_with notice: t(".success"), fallback: finance_staff_member_path(@member, tab: "advances")
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      advance = authorize @member.advances.find(params[:id])
      advance.destroy!
      close_modal_with notice: t(".success"), fallback: finance_staff_member_path(@member, tab: "advances")
    end

    private
      def set_member
        @member = StaffMember.includes(:person, :role, :payments).find(params[:staff_member_id])
      end

      def advance_params
        params.expect(staff_advance: [ :given_on, :amount, :payment_method, :money_account_id, :observations ])
      end
  end
end
