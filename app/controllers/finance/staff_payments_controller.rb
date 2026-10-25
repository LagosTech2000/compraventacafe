module Finance
  # Paying a period of an employee of the Planilla interna (StaffPaymentIssuer),
  # with its printable receipt (original and copy). Only the latest one is
  # removed.
  class StaffPaymentsController < ApplicationController
    before_action :set_member

    def new
      authorize StaffPayment
      return redirect_to(finance_staff_member_path(@member), alert: t(".no_salary", role: @member.role.name)) unless @member.role.priced?

      @period = @member.period_to_pay
      return redirect_to(finance_staff_member_path(@member), alert: t(".nothing_to_pay")) unless @period

      @issuer = StaffPaymentIssuer.new(member: @member, period: @period, payment_method: "cash",
                                       money_account_id: MoneyAccount.default_for("cash")&.id)
    end

    def create
      authorize StaffPayment
      @period = @member.period_to_pay
      return redirect_to(finance_staff_member_path(@member), alert: t(".nothing_to_pay")) unless @period

      @issuer = StaffPaymentIssuer.new(member: @member, period: @period, user: Current.user, **issuer_params)
      if @issuer.call
        receipt = finance_staff_member_staff_payment_path(@member, @issuer.payment)
        redirect_to receipt, notice: t(".success")
      else
        render :new, status: :unprocessable_content
      end
    end

    # Its receipt: original and copy, each printed on its own sheet.
    def show
      @payment = authorize @member.payments.includes(:money_account, :role, :created_by, :goals, :advances).find(params[:id])
    end

    def destroy
      payment = authorize @member.payments.find(params[:id])
      if payment.destroy
        redirect_to finance_staff_member_path(@member, tab: "payments"), notice: t(".success")
      else
        redirect_to finance_staff_member_path(@member, tab: "payments"), alert: payment.errors.full_messages.to_sentence
      end
    end

    private
      def set_member
        @member = StaffMember.includes(:role, :person, :payments, :goals, :attendances, advances: :money_account).find(params[:staff_member_id])
      end

      def issuer_params
        values = params.expect(staff_payment: [ :overtime_hours, :extra_bonus, :extra_bonus_reason, :paid_on,
                                                :payment_method, :money_account_id, :observations, met_goal_ids: [] ])
        values.to_h.symbolize_keys.merge(paid_on: date(values[:paid_on]))
      end

      def date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        Time.zone.today
      end
  end
end
