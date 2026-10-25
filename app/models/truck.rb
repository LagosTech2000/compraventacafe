# A truck that carries the coffee to the buyer (Fernando, 2026-10-25): its
# plate, make and model, color, capacity in quintals and whether it is the
# business's own; a catalog apart from the carriers, chosen in a shipment.
# Deactivated, never deleted once it has shipments.
class Truck < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  MAX_CAPACITY = 100_000

  has_many :shipments, dependent: :restrict_with_error

  # "haa  1234" → "HAA 1234".
  normalizes :plate, with: ->(value) { value.squish.upcase.presence }
  normalizes :brand_model, :color, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :plate, presence: true, length: { maximum: 20 }, uniqueness: true
  validates :brand_model, :color, length: { maximum: 80 }
  validates :capacity_quintals, numericality: { greater_than: 0, less_than: MAX_CAPACITY }, allow_nil: true
  validates :observations, length: { maximum: 500 }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:plate) }

  def audit_label = plate

  # "HAA 1234 · Isuzu NPR" for the lists that choose one.
  def label = [ plate, brand_model ].compact.join(" · ")
end
