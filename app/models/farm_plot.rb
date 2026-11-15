# A plot of a farm (Fernando, 2026-11-15: «lote es una parcela de la
# finca»): «Lote 1», «Lote 2»… with its land and its coffee varieties. A
# purchase may say which plot its coffee came from. Names are unique within
# the farm. A plot named by a purchase is deactivated, never deleted.
class FarmPlot < ApplicationRecord
  include Auditable
  include HasVarieties

  belongs_to :farm, inverse_of: :plots
  has_many :purchases, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP
  normalizes :area_unit, with: ->(value) { value.presence }

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false, scope: :farm_id }
  validates :observations, length: { maximum: 500 }
  validates :area_value, numericality: { greater_than: 0, less_than: 10**9 }, allow_nil: true
  validates :area_unit, inclusion: { in: FarmArea::UNITS }, if: :area_value
  before_validation { self.area_unit = nil if area_value.nil? }

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }

  def audit_label = farm ? "#{name} · #{farm.name}" : name

  # Its land in every unit (FarmArea), or nil when it was not written.
  def area = (FarmArea.new(area_value, area_unit) if area_value && FarmArea::UNITS.include?(area_unit))
end
