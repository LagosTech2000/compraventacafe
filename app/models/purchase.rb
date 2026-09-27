# One weighing of coffee bought from a producer.
class Purchase < ApplicationRecord
  COFFEE_STATES = %w[cherry wet_parchment dry_parchment].freeze

  belongs_to :producer
  belongs_to :zone, optional: true
  belongs_to :invoice, optional: true
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :purchased_on, presence: true
  validates :coffee_state, inclusion: { in: COFFEE_STATES }
  validates :gross_weight, numericality: { greater_than: 0, less_than: 100_000 }
  validates :humidity_percent, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :price_per_pound, numericality: { greater_than: 0, less_than: 100_000 }
  validates :observations, length: { maximum: 500 }
  validate :invoice_belongs_to_same_producer

  before_validation :calculate

  scope :on, ->(date) { where(purchased_on: date) }
  scope :uninvoiced, -> { where(invoice_id: nil) }
  scope :chronological, -> { order(:purchased_on, :id) }

  def invoiced?
    invoice_id.present?
  end

  def human_coffee_state
    self.class.human_attribute_name("coffee_state/#{coffee_state}")
  end

  private
    def calculate
      return unless gross_weight.present? && humidity_percent.present? && price_per_pound.present?

      calculation = PurchaseCalculation.new(gross_weight:, humidity_percent:, price_per_pound:)
      self.sacks = calculation.sacks
      self.tare = calculation.tare
      self.net_weight = calculation.net_weight
      self.total = calculation.total
    end

    def invoice_belongs_to_same_producer
      return if invoice.nil? || invoice.producer_id == producer_id

      errors.add(:invoice, :other_producer)
    end
end
