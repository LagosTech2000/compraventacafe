# Something lent in kind as part of a loan (a sack of fertilizer, a liter of
# fungicide...). Its default price fills the loan form and can be changed
# there. A supply in use is deactivated, never deleted.
class Supply < ApplicationRecord
  include Auditable

  MAX_PRICE = 10_000_000

  has_many :loan_supplies, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :unit, with: ->(value) { value.squish.downcase.presence }

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  validates :unit, presence: true, length: { maximum: 30 }
  validates :default_price, numericality: { greater_than: 0, less_than: MAX_PRICE }

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }

  def audit_label = name

  # What the loan form's picker needs about it.
  def picker_data
    { name:, unit:, price: format("%.2f", default_price) }
  end
end
