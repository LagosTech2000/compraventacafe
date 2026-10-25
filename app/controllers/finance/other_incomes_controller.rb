module Finance
  # Money that comes in from outside the modules (owner's contributions,
  # bank loans…).
  class OtherIncomesController < ApplicationController
    def new
      @income = authorize OtherIncome.new(received_on: Time.zone.today, payment_method: "cash",
                                          money_account_id: params[:account] || MoneyAccount.default_for("cash")&.id)
    end

    def create
      @income = authorize OtherIncome.new(income_params.merge(created_by: Current.user))

      if @income.save
        close_modal_with notice: t(".success"), fallback: finance_money_account_path(@income.money_account)
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      income = authorize OtherIncome.find(params[:id])
      income.destroy!
      close_modal_with notice: t(".success"), fallback: finance_money_account_path(income.money_account)
    end

    private
      def income_params
        params.expect(other_income: [ :received_on, :money_account_id, :concept, :amount, :payment_method, :observations ])
      end
  end
end
