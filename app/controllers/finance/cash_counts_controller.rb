module Finance
  # Cash counts ("arqueos"): the money counted in an account against what
  # the system says, from the account's page.
  class CashCountsController < ApplicationController
    def new
      account = MoneyAccount.find_by(id: params[:account]) || MoneyAccount.default_for("cash")
      @count = authorize CashCount.new(counted_on: Time.zone.today, money_account: account)
    end

    def create
      @count = authorize CashCount.new(count_params.merge(created_by: Current.user))

      if @count.save
        close_modal_with notice: t(".success", difference: helpers.signed_money(@count.difference)),
                         fallback: finance_money_account_path(@count.money_account)
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      count = authorize CashCount.find(params[:id])
      count.destroy!
      close_modal_with notice: t(".success"), fallback: finance_money_account_path(count.money_account)
    end

    private
      def count_params
        params.expect(cash_count: [ :money_account_id, :counted_on, :counted_amount, :observations ])
      end
  end
end
