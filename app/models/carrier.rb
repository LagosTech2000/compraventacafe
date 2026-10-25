# Who hauls the coffee to the buyer (Fernando, 2026-10-25): a company or a
# person, a catalog of its own, chosen in a shipment. Trucks are a separate
# catalog. Deactivated, never deleted once it has shipments.
class Carrier < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  has_many :shipments, dependent: :restrict_with_error

  normalizes :name, :contact_name, with: ->(value) { value.squish.presence }
  normalizes :rtn, with: FieldFormats::DIGITS
  normalizes :phone, with: FieldFormats::PHONE
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { case_sensitive: false }
  validates :rtn, field_format: :rtn, uniqueness: true, allow_nil: true
  validates :phone, field_format: :phone
  validates :contact_name, length: { maximum: 120 }
  validates :observations, length: { maximum: 500 }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  def audit_label = name
end
