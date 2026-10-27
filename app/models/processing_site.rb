# Where coffee is processed (client, 2026-10-26): the ecological machines
# of others where cherry is pulped, the business's patio, a dryer that
# charges… A catalog chosen in each process. Deactivated, never deleted.
class ProcessingSite < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  has_many :coffee_conversions, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { case_sensitive: false }
  validates :observations, length: { maximum: 500 }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  def self.options_for(selected_id) = active.or(where(id: selected_id)).alphabetical

  def audit_label = name
end
