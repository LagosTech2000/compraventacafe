# A task of a payroll paid by task ("por obra"): its value is split in equal
# parts among the members who did it (decided by the owner, 2026-10-10) and
# paid in the pay period of the day it was completed. Once paid, it is
# closed.
#
# The value (`amount`) is written, or it is a quantity × a price (Fernando,
# 2026-10-16; PRICINGS): manzanas of the farm worked (no more than the
# farm's extension, which must be filled in first), barrels sprayed
# (fumigation or foliar; the barrel's liters are noted, the price is per
# barrel) or fertilizer applied, in quintals or pounds.
class PayrollTask < ApplicationRecord
  include Auditable

  PRICINGS = %w[fixed per_manzana per_barrel per_fertilizer].freeze
  FERTILIZER_UNITS = %w[quintal pound].freeze
  DEFAULT_BARREL_LITERS = 200
  MAX_QUANTITY = 10**9

  belongs_to :payroll
  has_many :participants, class_name: "PayrollTaskParticipant", dependent: :destroy, inverse_of: :task
  has_many :members, through: :participants

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 150 }
  validates :pricing, inclusion: { in: PRICINGS }
  with_options unless: :fixed? do
    validates :quantity, numericality: { greater_than: 0, less_than: MAX_QUANTITY }
    validates :unit_price, numericality: { greater_than: 0, less_than: Payroll::MAX_AMOUNT }
  end
  validates :barrel_liters, numericality: { greater_than: 0, less_than: 100_000 }, if: :per_barrel?
  validates :quantity_unit, inclusion: { in: FERTILIZER_UNITS }, if: :per_fertilizer?
  validates :amount, numericality: { greater_than: 0, less_than: Payroll::MAX_AMOUNT }
  validate :manzanas_within_farm, if: :per_manzana?

  before_validation :price_by_quantity
  validates :observations, length: { maximum: 500 }
  validate :completed_within_payroll, :has_participants_when_completed, :not_paid

  before_destroy :ensure_not_paid

  scope :newest_first, -> { order(Arel.sql("completed_on DESC NULLS FIRST"), id: :desc) }
  scope :completed, -> { where.not(completed_on: nil) }
  scope :pending, -> { where(completed_on: nil) }

  def audit_label
    "#{name} · #{payroll&.audit_label}"
  end

  def completed? = completed_on.present?

  PRICINGS.each { |pricing| define_method(:"#{pricing}?") { self.pricing == pricing } }

  # The farm's extension in manzanas, when it has one.
  def farm_manzanas = payroll&.farm&.area&.manzanas

  def paid?
    completed_on_in_database.present? && payroll.paid_on?(completed_on_in_database)
  end

  # Equal parts, to the cent; the cents left over go one each to the first
  # members (by name), so the parts add up to the value exactly.
  def shares
    ordered = participants.map(&:member).sort_by(&:sort_key)
    return {} if ordered.empty?

    base = (amount / ordered.size).floor(2)
    extra_cents = ((amount - (base * ordered.size)) * 100).to_i
    ordered.each_with_index.to_h { |member, index| [ member, base + (index < extra_cents ? BigDecimal("0.01") : 0) ] }
  end

  # The member ids from the form's checkboxes.
  def member_ids=(ids)
    wanted = Array(ids).compact_blank.map(&:to_i)
    participants.each { |participant| participant.mark_for_destruction unless wanted.include?(participant.payroll_member_id) }
    (wanted - participants.map(&:payroll_member_id)).each { |id| participants.build(payroll_member_id: id) }
  end

  def kept_participants = participants.reject(&:marked_for_destruction?)

  private
    # A priced task keeps only what its pricing uses; its value is
    # quantity × price, to the cent.
    def price_by_quantity
      self.pricing = "fixed" if pricing.blank?
      self.barrel_liters = nil unless per_barrel?
      self.quantity_unit = nil unless per_fertilizer?
      if fixed?
        self.quantity = self.unit_price = nil
      elsif quantity && unit_price
        self.amount = (quantity * unit_price).round(2)
      end
    end

    def manzanas_within_farm
      manzanas = farm_manzanas
      if manzanas.nil?
        errors.add(:base, :farm_area_missing)
      elsif quantity && quantity > manzanas.round(2)
        errors.add(:quantity, :more_than_farm, manzanas: manzanas.round(2).to_s("F"))
      end
    end

    def completed_within_payroll
      return unless payroll && completed_on

      errors.add(:completed_on, :outside_payroll) unless payroll.period_containing(completed_on)
      errors.add(:completed_on, :period_paid) if !paid? && payroll.paid_on?(completed_on)
    end

    def has_participants_when_completed
      errors.add(:base, :no_participants) if completed? && kept_participants.empty?
    end

    def not_paid
      errors.add(:base, :paid) if persisted? && paid?
    end

    def ensure_not_paid
      return unless paid?

      errors.add(:base, :paid)
      throw :abort
    end
end
