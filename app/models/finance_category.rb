# How Control financiero classifies what goes out (Fernando, 2026-10-23):
# its own catalog, apart from the farms' expense categories, in two levels
# (Transporte › Combustible), for expenses or for investments. The budget
# goes by the first level. Deactivated, never deleted once used.
class FinanceCategory < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  KINDS = %w[expense investment].freeze

  belongs_to :parent, class_name: "FinanceCategory", optional: true, inverse_of: :children
  has_many :children, -> { order(:name) }, class_name: "FinanceCategory", foreign_key: :parent_id, inverse_of: :parent,
                                           dependent: :restrict_with_error
  has_many :expenses, dependent: :restrict_with_error
  has_many :budgets, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 80 }
  validates :kind, inclusion: { in: KINDS }
  validate :unique_in_parent, :parent_is_first_level, :parent_same_kind

  before_validation { self.kind = parent.kind if parent }

  scope :active, -> { where(active: true) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :of_kind, ->(kind) { where(kind:) }
  scope :alphabetical, -> { order(:name) }
  scope :newest_first, -> { order(:name) }

  def audit_label = full_name
  def human_kind = self.class.human_attribute_name("kind/#{kind}")

  # "Transporte › Combustible"
  def full_name = parent ? "#{parent.name} › #{name}" : name

  def top_level? = parent_id.nil?
  # The first-level category it belongs to (itself, at the first level).
  def root = parent || self

  # This category and its subcategories, as ids.
  def family_ids = [ id, *children.map(&:id) ]

  # For selects: [[“Transporte”, id], [“Transporte › Combustible”, id], …],
  # each first level followed by its subcategories.
  def self.options_for(kind, including: nil)
    tops = of_kind(kind).top_level.includes(:children).alphabetical
    tops.flat_map do |top|
      [ top, *top.children ].select { |category| category.active? || category.id == including }
                            .map { |category| [ category == top ? top.name : "#{top.name} › #{category.name}", category.id ] }
    end
  end

  private
    def unique_in_parent
      scope = self.class.where(kind:, parent_id:).where("lower(name) = ?", name.to_s.downcase)
      scope = scope.where.not(id:) if persisted?
      errors.add(:name, :taken) if name.present? && scope.exists?
    end

    def parent_is_first_level
      errors.add(:parent, :not_first_level) if parent && !parent.top_level?
      errors.add(:parent, :has_children) if parent && persisted? && children.any?
    end

    def parent_same_kind
      errors.add(:parent, :other_kind) if parent && parent.kind != kind
    end
end
