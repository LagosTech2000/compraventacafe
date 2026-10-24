# What the business plans to spend in a first-level category in a month
# (Fernando, 2026-10-23). Compared with the expenses of that category and
# its subcategories in that month (BudgetMonth).
class Budget < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  belongs_to :category, class_name: "FinanceCategory", foreign_key: :finance_category_id, inverse_of: :budgets

  validates :month, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0, less_than: Expense::MAX_AMOUNT }
  validates :finance_category_id, uniqueness: { scope: :month }
  validate { errors.add(:category, :not_first_level) if category && !category.top_level? }

  before_validation { self.month = month.beginning_of_month if month }

  def audit_label = "#{category&.name} · #{I18n.l(month, format: :month_year) if month}"
end
