# What kind of vehicle it is (Fernando, 2026-11-04): «Camión», «Pick-up»…
# a catalog the user grows, renames and deactivates. A deactivated one is
# not chosen for new vehicles; the ones that have it keep it.
class VehicleType < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  has_many :vehicles, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  def audit_label = name
end
