# One weighing of coffee bought from a producer.
class Purchase < ApplicationRecord
  include Auditable

  COFFEE_STATES = %w[cherry wet_parchment dry_parchment].freeze
  # What the calculation reads. Results are recalculated only when one of
  # these changes, so a stored purchase keeps its numbers if the rule changes.
  CALCULATION_INPUTS = %w[coffee_state gross_weight humidity_percent damage_percent yield_factor price_per_pound].freeze

  belongs_to :producer
  belongs_to :zone, optional: true
  belongs_to :invoice, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :voided_by, class_name: "User", optional: true

  normalizes :observations, with: FieldFormats::STRIP

  validates :purchased_at, presence: true
  validates :coffee_state, inclusion: { in: COFFEE_STATES }
  validates :gross_weight, numericality: { greater_than: 0, less_than: 100_000 }
  validates :price_per_pound, numericality: { greater_than: 0, less_than: 100_000 }
  with_options if: :recalculate? do
    with_options unless: :cherry? do
      validates :humidity_percent, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
      validates :damage_percent, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
    end
    validates :yield_factor, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, if: :cherry?
  end
  validates :observations, length: { maximum: 500 }
  validate :invoice_belongs_to_same_producer
  validate :voided_not_invoiced

  before_validation :clear_unused_inputs, if: :recalculate?
  before_validation :calculate, if: :recalculate?
  before_validation :assign_season

  # Purchases of a day (or a range of days), in Tegucigalpa time.
  scope :on, ->(dates) { where(purchased_at: day_range(dates)) }
  scope :active, -> { where(voided_at: nil) }
  scope :voided, -> { where.not(voided_at: nil) }
  # Waiting to be invoiced: neither invoiced nor voided.
  scope :uninvoiced, -> { active.where(invoice_id: nil) }
  scope :in_season, ->(season) { where(season_year: season.year) }
  # Most recent purchase first; same moment, last registered first.
  scope :newest_first, -> { order(purchased_at: :desc, id: :desc) }

  # A date, or a range of dates with open ends, as a range of moments.
  def self.day_range(dates)
    dates = dates..dates unless dates.is_a?(Range)
    (dates.begin&.in_time_zone&.beginning_of_day)..(dates.end&.in_time_zone&.end_of_day)
  end

  # The id is shown next to it in the audit log; the producer names it.
  def audit_label
    producer.full_name
  end

  def invoiced?
    invoice_id.present?
  end

  def voided?
    voided_at.present?
  end

  def cherry?
    coffee_state == "cherry"
  end

  def season
    Season.new(season_year) if season_year
  end

  # QQ: the net weight in quintals of 125 lb.
  def quintals
    PurchaseCalculation.quintals(net_weight) if net_weight
  end

  def human_coffee_state
    self.class.human_attribute_name("coffee_state/#{coffee_state}")
  end

  # Takes the purchase out of every list and total without deleting it.
  def void!(user)
    update!(voided_at: Time.current, voided_by: user)
  end

  private
    def recalculate?
      new_record? || CALCULATION_INPUTS.any? { |input| will_save_change_to_attribute?(input) }
    end

    # Cherry has no humidity nor damage; parchment has no yield.
    def clear_unused_inputs
      if cherry?
        self.humidity_percent = nil
        self.damage_percent = nil
      else
        self.yield_factor = nil
      end
    end

    def calculate
      inputs = cherry? ? [ yield_factor ] : [ humidity_percent, damage_percent ]
      return unless gross_weight.present? && price_per_pound.present? && inputs.all?(&:present?)

      calculation = PurchaseCalculation.new(coffee_state:, gross_weight:, price_per_pound:,
                                            humidity_percent:, damage_percent:, yield_factor:)
      self.sacks = calculation.sacks
      self.tare = calculation.tare
      self.net_weight = calculation.net_weight
      self.total = calculation.total
    end

    def assign_season
      self.season_year = Season.for(purchased_at.to_date).year if purchased_at
    end

    def invoice_belongs_to_same_producer
      return if invoice.nil? || invoice.producer_id == producer_id

      errors.add(:invoice, :other_producer)
    end

    def voided_not_invoiced
      errors.add(:base, :voided_invoiced) if voided? && invoiced?
    end
end
