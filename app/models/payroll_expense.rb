# An expense of a payroll (transport, tools, food...), counted in its
# accounts with the pay.
class PayrollExpense < ApplicationRecord
  include Auditable

  belongs_to :payroll
  belongs_to :category, class_name: "ExpenseCategory", foreign_key: :expense_category_id, inverse_of: :expenses
  belongs_to :created_by, class_name: "User"

  normalizes :description, with: ->(value) { value.squish.presence }

  validates :spent_on, presence: true
  validates :description, presence: true, length: { maximum: 200 }
  validates :amount, numericality: { greater_than: 0, less_than: Payroll::MAX_AMOUNT }
  validate :category_active, if: -> { category && will_save_change_to_expense_category_id? }

  scope :newest_first, -> { order(spent_on: :desc, id: :desc) }

  def audit_label
    "#{description} · #{payroll&.audit_label}"
  end

  private
    def category_active
      errors.add(:category, :inactive) unless category.active?
    end
end
