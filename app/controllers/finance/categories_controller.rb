module Finance
  # Control financiero's categories, in two levels.
  class CategoriesController < ApplicationController
    before_action :set_category, only: %i[ edit update ]

    def index
      authorize FinanceCategory
      @filter = FinanceCategoryFilter.new(params)
      @categories, @next_page = @filter.results(policy_scope(FinanceCategory))
    end

    def new
      kind = params[:kind].presence_in(FinanceCategory::KINDS) || "expense"
      @category = authorize FinanceCategory.new(kind:, parent_id: params[:parent_id])
    end

    def create
      @category = authorize FinanceCategory.new(category_params)

      if @category.save
        close_modal_with notice: t(".success"), fallback: finance_categories_path,
                         event: "finance_category:created", detail: { id: @category.id, label: @category.full_name, name: @category.full_name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        close_modal_with notice: t(".success"), fallback: finance_categories_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_category
        @category = authorize FinanceCategory.find(params[:id])
      end

      def category_params
        params.expect(finance_category: [ :name, :kind, :parent_id, :active ])
      end
  end
end
