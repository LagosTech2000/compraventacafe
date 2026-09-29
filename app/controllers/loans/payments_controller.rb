module Loans
  class PaymentsController < ApplicationController
    before_action :set_loan

    def new
      @payment = authorize @loan.payments.build(paid_on: Time.zone.today)
      @balance = @loan.balance
    end

    def create
      @payment = authorize @loan.payments.build(payment_params.merge(created_by: Current.user))

      if @payment.save
        close_modal_with notice: t(".success"), fallback: loans_loan_path(@loan)
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

      def payment_params
        params.expect(loan_payment: [ :paid_on, :amount, :payment_method, :observations ])
      end
  end
end
