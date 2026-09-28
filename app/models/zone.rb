# Locality a producer comes from. Price depends on it (with quality and the
# market); the price table itself is still unknown.
class Zone < ApplicationRecord
  include Auditable

  has_many :producers, dependent: :restrict_with_error
  has_many :purchases, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(:name) }

  def audit_label = name
end
