module Loans
  class LoansController < ApplicationController
    before_action :set_loan, only: %i[ show edit update destroy ]

    def index
      authorize Loan
      @filter = LoanFilter.new(params)
      @loans, @next_page = @filter.results(policy_scope(Loan))
    end

    def show
      @balance = @loan.balance
      @payments = @loan.payments.includes(:purchase).newest_first
    end

    def new
      @loan = authorize Loan.new(disbursed_on: Time.zone.today, person: Person.find_by(id: params[:person_id]))
    end

    def create
      @loan = authorize Loan.new(loan_params.merge(created_by: Current.user))

      if @loan.save
        close_modal_with notice: t(".success", person: @loan.person.full_name), fallback: loans_loan_path(@loan)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @loan.update(loan_params)
        close_modal_with notice: t(".success"), fallback: loans_loan_path(@loan)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @loan.destroy!
      close_modal_with notice: t(".success"), fallback: loans_loans_path
    end

    private
      def set_loan
        @loan = authorize Loan.find(params[:id])
      end

      def loan_params
        params.expect(loan: [ :person_id, :cash_amount, :monthly_interest_rate, :disbursed_on, :due_on, :observations,
                              supply_items_attributes: [ [ :id, :supply_id, :quantity, :unit_price, :_destroy ] ] ])
      end
  end
end
