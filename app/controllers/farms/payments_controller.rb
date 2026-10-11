module Farms
  # Paying a pay period of a payroll, with loan payments taken from the pay.
  class PaymentsController < ApplicationController
    include FarmsPayrollScoped

    def new
      @issuer = build_issuer(paid_on: params[:paid_on])
      authorize PayrollPayment.new(payroll: @payroll, period_starts_on: @issuer.period.starts_on)
    end

    def create
      authorize PayrollPayment.new(payroll: @payroll)
      @issuer = build_issuer(**issuer_params)

      if @issuer.save
        redirect_to farms_payroll_payment_path(@payroll, @issuer.payment),
                    notice: t(".success", amount: helpers.format_money(@issuer.payment.net_total))
      else
        render :new, status: :unprocessable_content
      end
    end

    # The pay sheet, to print and sign.
    def show
      @payment = authorize @payroll.payments.includes(lines: [ { member: [ :person, :role ] }, :loan_payments ]).find(params[:id])
    end

    def destroy
      payment = authorize @payroll.payments.find(params[:id])
      payment.remove!
      redirect_to farms_payroll_path(@payroll), notice: t(".success")
    end

    private
      def build_issuer(paid_on: nil, loan_amounts: {}, observations: nil)
        period = period_param
        raise ActiveRecord::RecordNotFound unless period

        PayrollPaymentIssuer.new(payroll: @payroll, period:, user: Current.user, paid_on:, loan_amounts:, observations:,
                                 with_loans: policy(PayrollPayment.new(payroll: @payroll)).deduct_loans?)
      end

      def period_param
        date = Date.iso8601(params[:period].to_s)
        period = @payroll.period_containing(date)
        period if period&.starts_on == date
      rescue Date::Error
        nil
      end

      def issuer_params
        permitted = params.expect(payroll_payment_issuer: [ :paid_on, :observations, loan_amounts: {} ])
        loan_amounts = policy(PayrollPayment.new(payroll: @payroll)).deduct_loans? ? permitted[:loan_amounts].to_h : {}
        { paid_on: permitted[:paid_on], observations: permitted[:observations], loan_amounts: }
      end
  end
end
