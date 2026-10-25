module Finance
  # Consolidación: the payments and collections registered without an
  # account, to give them one (AccountConsolidation).
  class ConsolidationsController < ApplicationController
    def show
      authorize [ :finance, :consolidation ]
      @filter = ConsolidationFilter.new(params)
      @filter.user = Current.user
      @movements, @next_page = @filter.results(nil)
    end

    def update
      authorize [ :finance, :consolidation ], :update?
      by_method = params[:by_method].present?
      items = Array(params[:items]).map(&:to_s)
      account = MoneyAccount.active.find_by(id: params[:account_id].to_s) unless by_method
      category = ExpenseCategory.active.find_by(id: params[:category_id].to_s)
      if !by_method && account.nil? && category.nil?
        redirect_back_or_to finance_consolidation_path, alert: t(".pick_account")
        return
      end

      result = AccountConsolidation.new(items:, account:, by_method:, category:,
                                        sources: MoneyMovements.sources_for(Current.user)).call
      redirect_back_or_to finance_consolidation_path, notice: notice_for(result, account: by_method || account, category:)
    end

    private
      def notice_for(result, account:, category:)
        parts = []
        parts << t(".success", count: result.assigned) if account
        parts << t(".skipped", count: result.skipped) if result.skipped.positive?
        parts << t(".categorized", count: result.categorized, category: category.name) if category
        parts << t(".uncategorized", count: result.uncategorized) if category && result.uncategorized.positive?
        parts.join(" ")
      end
  end
end
