module Finance
  # The budget of a season: categories × months, planned against spent.
  class BudgetsController < ApplicationController
    before_action :set_sheet

    def show
      authorize [ :finance, :budget ]
    end

    # Every amount of the grid at once: all saved or none. An empty cell
    # removes that month's budget.
    def update
      authorize [ :finance, :budget ], :update?
      Budget.transaction do
        params.fetch(:budgets, {}).each do |category_id, months|
          category = FinanceCategory.top_level.find(category_id)
          months.each do |month, amount|
            month = Date.iso8601(month)
            next unless @sheet.months.include?(month)

            budget = Budget.find_or_initialize_by(finance_category_id: category.id, month:)
            if amount.blank?
              budget.destroy! if budget.persisted?
            elsif budget.amount != amount.to_d
              budget.update!(amount:)
            end
          end
        end
      end
      redirect_to finance_budget_path(season_year: @sheet.season.year), notice: t(".success")
    end

    private
      def set_sheet
        year = params[:season_year].to_s.match?(/\A\d{4}\z/) ? params[:season_year].to_i : Season.current.year
        @sheet = BudgetSheet.new(Season.new(year))
      end
  end
end
