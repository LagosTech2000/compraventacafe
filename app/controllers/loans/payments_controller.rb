module Loans
  class PaymentsController < ApplicationController
    before_action :set_loan
    before_action :set_payroll, only: %i[ new create ]

    def new
      @payment = authorize @loan.payments.build(paid_on: Time.zone.today)
      @balance = @loan.balance
    end

    # Its receipt: original and copy, printed on one sheet.
    def show
      @payment = authorize @loan.payments.find(params[:id])
      @balance_after = @payment.balance_after
    end

    def create
      @payment = authorize @loan.payments.build(payment_params.merge(created_by: Current.user))

      if @payment.save
        # Back on the loan (or on the payroll it was paid from), with the new
        # payment's receipt open to print it.
        receipt = if @payroll
          farms_payroll_path(@payroll, tab: "loans", receipt_loan: @loan.id, receipt: @payment.id)
        else
          loans_loan_path(@loan, receipt: @payment.id)
        end
        close_modal_with notice: t(".success"), fallback: receipt, visit: receipt
      else
        @balance = @loan.balance
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      payment = authorize @loan.payments.find(params[:id])
      payment.destroy!
      close_modal_with notice: t(".success"), fallback: loans_loan_path(@loan)
    end

    private
      def set_loan
        @loan = Loan.find(params[:loan_id])
      end

      # A payment opened from a payroll's "Préstamos" tab goes back there,
      # when the user can see that payroll.
      def set_payroll
        payroll = Payroll.find_by(id: params[:payroll_id]) if params[:payroll_id].to_s.match?(/\A\d+\z/)
        @payroll = payroll if payroll && policy(payroll).show?
      end

      def payment_params
        params.expect(loan_payment: [ :paid_on, :amount, :payment_method, :observations, :money_account_id ])
      end
  end
end
