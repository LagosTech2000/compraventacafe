module Finance
  # Resumen: where the money is (accounts), what went out this month against
  # the last, by module and by category, the budget of the month and the
  # latest movements.
  class HomeController < ApplicationController
    def index
      authorize [ :finance, :home ]
      @today = Time.zone.today
      @balance = AccountBalance.new(as_of: @today)
      @accounts = MoneyAccount.active.alphabetical.to_a
      sources = MoneyMovements.sources_for(Current.user)
      @month = month_movements(@today.beginning_of_month..@today, sources)
      previous_start = @today.beginning_of_month.prev_month
      @previous = month_movements(previous_start..[ previous_start + (@today.day - 1), previous_start.end_of_month ].min, sources)
      @budget = BudgetSheet.new(Season.for(@today))
      @budget_lines = @budget.month_lines(@today.beginning_of_month)
      @without_account = @month.count { |movement| movement.account_id.nil? }
      @latest = MoneyMovements.new(range: (@today - 30)..@today, sources:).all.reject(&:transfer?).last(8).reverse
    end

    private
      def month_movements(range, sources) = MoneyMovements.new(range:, sources:).all.reject(&:transfer?)
  end
end
