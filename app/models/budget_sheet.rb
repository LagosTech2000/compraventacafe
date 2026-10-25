# The budget of a season (Fernando, 2026-10-23: monthly, by category):
# for each first-level category and month, what was planned (Budget) and
# what was spent (expenses and investments of that category and its
# subcategories, Control financiero's own). The season runs from September
# to August, as the business's.
class BudgetSheet
  Line = Data.define(:category, :budget, :spent) do
    def left = budget.to_d - spent
    def percent = budget.to_d.positive? ? (spent * 100 / budget).round(1) : nil
    def over? = budget.present? && spent > budget
  end

  attr_reader :season

  def initialize(season = Season.current)
    @season = season
  end

  def months = (0..11).map { |offset| season.starts_on >> offset }

  def categories(kind) = FinanceCategory.top_level.of_kind(kind).where(active: true).or(FinanceCategory.top_level.of_kind(kind).where(id: used_ids)).alphabetical

  def budget(category, month) = budgets[[ category.id, month ]]
  def spent(category, month) = spending.fetch([ category.id, month ], 0).to_d
  def line(category, month) = Line.new(category:, budget: budget(category, month), spent: spent(category, month))

  def budget_total(category) = months.sum { |month| budget(category, month).to_d }
  def spent_total(category) = months.sum { |month| spent(category, month) }
  def month_budget(month, kind) = categories(kind).sum { |category| budget(category, month).to_d }
  def month_spent(month, kind) = categories(kind).sum { |category| spent(category, month) }

  # One month's lines (with a budget or spending), most used first.
  def month_lines(month)
    FinanceCategory.top_level.alphabetical.map { |category| line(category, month) }
                   .select { |line| line.budget.present? || line.spent.positive? }
                   .sort_by { |line| -(line.percent || 0) }
  end

  private
    def budgets
      @budgets ||= Budget.where(month: months).pluck(:finance_category_id, :month, :amount).to_h { |id, month, amount| [ [ id, month ], amount ] }
    end

    def spending
      @spending ||= Expense.where(spent_on: season.starts_on..season.ends_on).joins(:category)
                           .group(Arel.sql("COALESCE(finance_categories.parent_id, finance_categories.id)"),
                                  Arel.sql("DATE_TRUNC('month', expenses.spent_on)::date"))
                           .sum(:amount)
    end

    def used_ids = budgets.keys.map(&:first) | spending.keys.map(&:first)
end
