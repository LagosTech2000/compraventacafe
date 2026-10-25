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
      if !by_method && account.nil?
        redirect_back_or_to finance_consolidation_path, alert: t(".pick_account")
        return
      end

      result = AccountConsolidation.new(items:, account:, by_method:,
                                        sources: MoneyMovements.sources_for(Current.user)).call
      notice = t(".success", count: result.assigned)
      notice = "#{notice} #{t(".skipped", count: result.skipped)}" if result.skipped.positive?
      redirect_back_or_to finance_consolidation_path, notice:
    end
  end
end
