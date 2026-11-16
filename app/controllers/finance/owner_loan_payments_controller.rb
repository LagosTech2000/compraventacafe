module Finance
  # A payment of an owners' loan: interest first, then principal (LoanBalance).
  class OwnerLoanPaymentsController < ApplicationController
    before_action :set_loan

    def new
      @payment = authorize @loan.payments.build(paid_on: Time.zone.today, payment_method: "transfer",
                                                money_account_id: MoneyAccount.default_for("transfer")&.id)
      @balance = @loan.balance
    end

    def create
      @payment = authorize @loan.payments.build(payment_params.merge(created_by: Current.user))

      if @payment.save
        close_modal_with notice: t(".success", amount: helpers.format_money(@payment.amount)), fallback: finance_owner_loan_path(@loan)
      else
        @balance = @loan.balance
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      payment = authorize @loan.payments.find(params[:id])
      payment.destroy!
      redirect_to finance_owner_loan_path(@loan), notice: t(".success")
    end

    private
      def set_loan
        @loan = OwnerLoan.find(params[:owner_loan_id])
        authorize @loan, :show?
      end

      def payment_params
        params.expect(owner_loan_payment: [ :paid_on, :amount, :payment_method, :money_account_id, :observations ])
      end
  end
end
