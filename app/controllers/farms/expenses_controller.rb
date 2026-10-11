module Farms
  # Expenses of a payroll, for its accounts.
  class ExpensesController < ApplicationController
    include FarmsPayrollScoped
    before_action :set_expense, only: %i[ edit update destroy ]

    def new
      @expense = authorize @payroll.expenses.build(spent_on: Time.zone.today)
    end

    def create
      @expense = authorize @payroll.expenses.build(expense_params.merge(created_by: Current.user))

      if @expense.save
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("expenses")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @expense.update(expense_params)
        close_modal_with notice: t(".success"), fallback: payroll_tab_path("expenses")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @expense.destroy!
      close_modal_with notice: t(".success"), fallback: payroll_tab_path("expenses")
    end

    private
      def set_expense
        @expense = authorize @payroll.expenses.find(params[:id])
      end

      def expense_params
        params.expect(payroll_expense: [ :spent_on, :expense_category_id, :description, :amount ])
      end
  end
end
