# Catalog of payroll expense categories (transport, tools, food...), in two
# levels (Transporte › Combustible; Fernando, 2026-11-03), like Control
# financiero's. An expense takes a first-level category or a subcategory. A
# category in use is deactivated, never deleted.
class ExpenseCategory < ApplicationRecord
  include Auditable

  belongs_to :parent, class_name: "ExpenseCategory", optional: true, inverse_of: :children
  has_many :children, -> { order(:name) }, class_name: "ExpenseCategory", foreign_key: :parent_id, inverse_of: :parent,
                                           dependent: :restrict_with_error
  has_many :expenses, class_name: "PayrollExpense", dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 100 }
  validate :unique_in_parent, :parent_is_first_level

  scope :active, -> { where(active: true) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :alphabetical, -> { order(:name) }
  # Each first level followed by its subcategories.
  scope :ordered, -> {
    left_joins(:parent)
      .order(Arel.sql("COALESCE(parents_expense_categories.name, expense_categories.name), " \
                      "expense_categories.parent_id NULLS FIRST, expense_categories.name"))
  }

  # SQL for "Transporte › Combustible", with the parent joined as
  # parents_expense_categories (left_joins(category: :parent)).
  FULL_NAME_SQL = "CONCAT_WS(' › ', parents_expense_categories.name, expense_categories.name)".freeze

  def audit_label = full_name

  # "Transporte › Combustible"
  def full_name = parent ? "#{parent.name} › #{name}" : name

  def top_level? = parent_id.nil?
  # The first-level category it belongs to (itself, at the first level).
  def root = parent || self

  # For selects: [["Transporte", id], ["Transporte › Combustible", id], …].
  # Only the active ones, plus the one given in including (an expense that
  # keeps an inactive category).
  def self.options(including: nil, all: false)
    top_level.includes(:children).alphabetical.flat_map do |top|
      [ top, *top.children ].select { |category| all || category.active? || category.id == including }
                            .map { |category| [ category == top ? top.name : "#{top.name} › #{category.name}", category.id ] }
    end
  end

  # The ids of a category and its subcategories, for filters: choosing
  # "Transporte" also brings "Transporte › Combustible".
  def self.family_ids(id)
    where(id:).or(where(parent_id: id)).pluck(:id)
  end

  private
    def unique_in_parent
      scope = self.class.where(parent_id:).where("lower(name) = ?", name.to_s.downcase)
      scope = scope.where.not(id:) if persisted?
      errors.add(:name, :taken) if name.present? && scope.exists?
    end

    def parent_is_first_level
      return unless parent

      errors.add(:parent, :not_first_level) if !parent.top_level? || parent_id == id
      errors.add(:parent, :has_children) if persisted? && children.any?
    end
end
