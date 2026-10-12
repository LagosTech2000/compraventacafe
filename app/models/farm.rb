# A farm of the business. Its payrolls (Payroll) pay the people who work it.
# A farm with payrolls is deactivated, never deleted.
class Farm < ApplicationRecord
  include HasAddress
  include Auditable

  has_many :payrolls, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  validates :observations, length: { maximum: 500 }

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }

  def audit_label = name
end
