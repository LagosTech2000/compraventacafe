module Finance
  # Expenses and investments (the same record; the route says which kind).
  class ExpensesController < ApplicationController
    before_action :set_kind
    before_action :set_expense, only: %i[ show edit update destroy ]

    def index
      authorize Expense
      @filter = ExpenseFilter.new(params)
      scope = policy_scope(Expense).where(kind: @kind)
      @expenses, @next_page = @filter.results(scope)
      @total = @filter.apply(scope).unscope(:order, :includes).sum(:amount)
    end

    def show
    end

    def new
      @expense = authorize Expense.new(kind: @kind, spent_on: Time.zone.today, payment_method: "cash",
                                       money_account: MoneyAccount.default_for("cash"))
    end

    def create
      @expense = authorize Expense.new(expense_params.merge(kind: @kind, created_by: Current.user))

      if @expense.save
        close_modal_with notice: t(".success.#{@kind}"), fallback: expense_path(@expense)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @expense.update(expense_params)
        close_modal_with notice: t(".success"), fallback: expense_path(@expense)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @expense.destroy!
      close_modal_with notice: t(".success"), fallback: expenses_path
    end

    private
      def set_kind
        @kind = params[:kind].presence_in(Expense::KINDS) || "expense"
      end

      def set_expense
        @expense = authorize Expense.where(kind: @kind).includes(:money_account, :created_by, :receipt_info, category: :parent).find(params[:id])
      end

      def expense_params
        params.expect(expense: [ :spent_on, :finance_category_id, :money_account_id, :payee, :description, :amount, :payment_method,
                                 :receipt_number, :observations, :receipt_upload, :remove_receipt, :lock_version ])
      end

      helper_method def expenses_path(**params) = @kind == "investment" ? finance_investments_path(**params) : finance_expenses_path(**params)
      helper_method def expense_path(expense) = @kind == "investment" ? finance_investment_path(expense) : finance_expense_path(expense)
      helper_method def new_expense_path(**params) = @kind == "investment" ? new_finance_investment_path(**params) : new_finance_expense_path(**params)
      helper_method def edit_expense_path(expense) = @kind == "investment" ? edit_finance_investment_path(expense) : edit_finance_expense_path(expense)
  end
end
