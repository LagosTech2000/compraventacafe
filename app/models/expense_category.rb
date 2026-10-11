# Catalog of payroll expense categories (transport, tools, food...). A
# category in use is deactivated, never deleted.
class ExpenseCategory < ApplicationRecord
  include Auditable

  has_many :expenses, class_name: "PayrollExpense", dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }

  def audit_label = name
end
