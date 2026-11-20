module Finance
  # «Saldos de apertura» (Fernando, 2026-11-18: the accounts were negative
  # without their opening balance): every active account with its first
  # movement, its lowest balance and the least opening balance that keeps
  # it from going negative (OpeningBalanceCheck); each one's date and
  # balance written right there.
  class OpeningBalancesController < ApplicationController
    def index
      authorize MoneyAccount, :update?
      @check = OpeningBalanceCheck.new
    end

    def update
      account = authorize MoneyAccount.find(params[:id])
      if account.update(params.expect(money_account: %i[ opening_on opening_balance ]))
        redirect_to finance_opening_balances_path(anchor: helpers.dom_id(account, :opening)), notice: t(".success", name: account.name)
      else
        @check = OpeningBalanceCheck.new
        @failed = account
        render :index, status: :unprocessable_content
      end
    end
  end
end
