module Finance
  # The owners' loans from a bank or another person (Fernando, 2026-11-15),
  # a development quoted apart (PaidFeature «owner_loans»).
  class OwnerLoansController < ApplicationController
    before_action :set_loan, only: %i[ show edit update ]

    def index
      authorize OwnerLoan
      @filter = OwnerLoanFilter.new(params)
      @loans, @next_page = @filter.results(policy_scope(OwnerLoan))
      @totals = @filter.totals(policy_scope(OwnerLoan))
    end

    def show
      @balance = @loan.balance
    end

    def new
      @loan = authorize OwnerLoan.new(disbursed_on: Time.zone.today, monthly_interest_rate: 0)
    end

    def create
      @loan = authorize OwnerLoan.new(loan_params.merge(created_by: Current.user))

      if @loan.save
        close_modal_with notice: t(".success"), fallback: finance_owner_loan_path(@loan)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @loan.update(loan_params)
        close_modal_with notice: t(".success"), fallback: finance_owner_loan_path(@loan)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_loan
        @loan = authorize OwnerLoan.includes(:money_account, payments: :money_account).find(params[:id])
      end

      def loan_params
        params.expect(owner_loan: [ :owner_name, :lender_name, :disbursed_on, :due_on, :principal, :monthly_interest_rate,
                                    :money_account_id, :observations, :lock_version ])
      end
  end
end
