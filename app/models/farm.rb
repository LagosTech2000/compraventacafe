# A farm of the business, or of a producer (producer_id): the farm their
# coffee comes from, which purchases name. Names are unique among the
# business's farms and, apart, among each producer's own (two producers can
# both have a "Finca El Paraíso"). The business's farm payrolls (Payroll)
# pay the people who work it. A farm with payrolls is deactivated, never deleted.
class Farm < ApplicationRecord
  include HasAddress
  include Auditable

  belongs_to :producer, optional: true
  has_many :payrolls, dependent: :restrict_with_error
  has_many :purchases, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false, scope: :producer_id }
  validates :observations, length: { maximum: 500 }
  validate :owner_kept_with_records, on: :update

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }
  scope :of_business, -> { where(producer_id: nil) }

  # A producer's farm, found by name (any case, extra spaces) or created:
  # what the producer form and the backfill do with a farm written by hand.
  def self.for_producer(producer, name)
    name = name.to_s.squish
    return if name.empty?

    producer.farms.find_by("LOWER(name) = ?", name.downcase) || producer.farms.create!(name:)
  end

  # In lists that mix both: a producer's farm says whose it is.
  def display_name = producer ? "#{name} · #{producer.full_name}" : name

  def audit_label = name

  # Who it belongs to can change while nothing names it yet.
  def owner_locked? = persisted? && (purchases.exists? || payrolls.exists?)

  private
    def owner_kept_with_records
      errors.add(:producer, :locked) if will_save_change_to_producer_id? && owner_locked?
    end
end
