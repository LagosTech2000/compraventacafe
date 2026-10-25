module Finance
  # Cash boxes and banks: their balances, and each one's statement (its
  # movements with the balance after each one), printable.
  class MoneyAccountsController < ApplicationController
    before_action :set_account, only: %i[ show edit update ]

    def index
      authorize MoneyAccount
      @filter = MoneyAccountFilter.new(params)
      @accounts, @next_page = @filter.results(policy_scope(MoneyAccount))
      @balance = AccountBalance.new
    end

    def show
      @filter = MovementFilter.new(params)
      @filter.user = Current.user
      @filter.fixed_account = @account.id.to_s
      @rows, @next_page = @filter.results(nil)
      @balance = AccountBalance.new
    end

    def new
      @account = authorize MoneyAccount.new(kind: "cash", opening_on: Time.zone.today, opening_balance: 0)
    end

    def create
      @account = authorize MoneyAccount.new(account_params)

      if @account.save
        close_modal_with notice: t(".success"), fallback: finance_money_account_path(@account)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @account.update(account_params)
        close_modal_with notice: t(".success"), fallback: finance_money_account_path(@account)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_account
        @account = authorize MoneyAccount.find(params[:id])
      end

      def account_params
        params.expect(money_account: [ :name, :kind, :bank_key, :bank_name, :account_number, :opening_balance, :opening_on, :observations, :active,
                                       default_for: [] ])
      end
  end
end
