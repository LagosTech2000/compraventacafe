module Farms
  class ExpenseCategoriesController < ApplicationController
    before_action :set_category, only: %i[ edit update ]

    def index
      authorize ExpenseCategory
      @filter = ExpenseCategoryFilter.new(params)
      @categories, @next_page = @filter.results(policy_scope(ExpenseCategory))
    end

    def new
      @category = authorize ExpenseCategory.new
    end

    def create
      @category = authorize ExpenseCategory.new(category_params)

      if @category.save
        close_modal_with notice: t(".success"), fallback: farms_expense_categories_path,
                         event: "expense_category:created", detail: { id: @category.id, name: @category.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        close_modal_with notice: t(".success"), fallback: farms_expense_categories_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_category
        @category = authorize ExpenseCategory.find(params[:id])
      end

      def category_params
        params.expect(expense_category: [ :name, :active ])
      end
  end
end
