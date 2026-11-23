# Something lent in kind as part of a loan (a sack of fertilizer, a liter of
# fungicide...). Its default price fills the loan form and can be changed
# there. A supply in use is deactivated, never deleted.
class Supply < ApplicationRecord
  include Auditable

  MAX_PRICE = 10_000_000

  has_many :loan_supplies, dependent: :restrict_with_error
  # What came into the inventory (Fernando, 2026-11-12).
  has_many :entries, class_name: "SupplyEntry", dependent: :restrict_with_error
  has_many :exit_lines, class_name: "SupplyExitLine", dependent: :restrict_with_error

  # What one unit cost, on average, of everything that came in (the cost of
  # a dispatch to a vehicle); nil without entries.
  def self.average_costs(ids = nil)
    lines = SupplyEntryLine.where("quantity > 0")
    lines = lines.where(supply_id: ids) if ids
    lines.group(:supply_id).pluck(:supply_id, Arel.sql("SUM(amount) / NULLIF(SUM(quantity), 0)")).to_h
  end

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :unit, with: ->(value) { value.squish.downcase.presence }

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  validates :unit, presence: true, length: { maximum: 30 }
  validates :default_price, numericality: { greater_than: 0, less_than: MAX_PRICE }

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }
  # Fuel, oil… of the business (Fernando, 2026-11-22): never lent; it goes
  # to the vehicles (SupplyExit, use of the business).
  scope :lendable, -> { where(business_use: false) }
  scope :of_the_business, -> { where(business_use: true) }

  def audit_label = name

  # What the loan form's picker needs about it.
  def picker_data
    { name:, unit:, price: format("%.2f", default_price) }
  end
end
