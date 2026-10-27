# What processing coffee cost (client, 2026-10-26): flete, secado, mano de
# obra, carga y descarga, alquiler de patio o secadora, combustible u otro,
# paid as an agreed total, per pound or per quintal. Per pound or quintal
# it is charged on a weight of the process: what went in or what came out
# (only once it has its result), gross or net, with quintals of 100, 120 or
# 125 lb. The basis, the quantity and the amount are kept, so the cost does
# not change afterwards.
#
# It goes out of an account (optional, as every payment of the other
# modules: Consolidación gives one later), shows in Control financiero's
# movements, and adds to the value of the coffee that came out (CoffeeLots).
# Registered or removed; never edited.
class ProcessingCost < ApplicationRecord
  include Auditable
  include HasMoneyAccount
  include LiveUpdates
  live_updates :sales, :finance

  CONCEPTS = %w[freight drying labor loading rental fuel other].freeze
  PRICINGS = %w[total per_pound per_quintal].freeze
  WEIGHT_SIDES = %w[input output].freeze
  WEIGHT_KINDS = %w[gross net].freeze
  QUINTAL_POUNDS = [ 100, 120, 125 ].freeze
  MAX_AMOUNT = 100_000_000

  belongs_to :coffee_conversion
  belongs_to :created_by, class_name: "User"

  normalizes :description, with: ->(value) { value.squish.presence }

  before_validation :calculate

  validates :concept, inclusion: { in: CONCEPTS }
  validates :description, length: { maximum: 200 }
  validates :description, presence: true, if: -> { concept == "other" }
  validates :pricing, inclusion: { in: PRICINGS }
  validates :paid_on, presence: true
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validates :amount, numericality: { greater_than: 0, less_than: MAX_AMOUNT }
  with_options unless: :total? do
    validates :weight_side, inclusion: { in: WEIGHT_SIDES }
    validates :weight_kind, inclusion: { in: WEIGHT_KINDS }
    validates :unit_price, numericality: { greater_than: 0, less_than: MAX_AMOUNT }
  end
  validates :quintal_pounds, inclusion: { in: QUINTAL_POUNDS }, if: :per_quintal?
  validate :output_weighed, unless: :total?
  validate :process_not_voided, on: :create

  scope :chronological, -> { order(:paid_on, :id) }

  def total? = pricing == "total"
  def per_quintal? = pricing == "per_quintal"

  def human_concept = self.class.human_attribute_name("concept/#{concept}")
  def label = [ human_concept, description ].compact.join(" · ")
  def audit_label = "#{label} · #{coffee_conversion&.audit_label}"

  # The pounds a cost per unit is charged on.
  def self.base_pounds(conversion, side, kind)
    return unless conversion && side.in?(WEIGHT_SIDES) && kind.in?(WEIGHT_KINDS)

    conversion["#{side}_#{kind}_weight"]
  end

  private
    def calculate
      if total?
        self.weight_side = self.weight_kind = self.quintal_pounds = self.base_pounds = self.quantity = self.unit_price = nil
        return
      end

      self.quintal_pounds = nil unless per_quintal?
      self.base_pounds = self.class.base_pounds(coffee_conversion, weight_side, weight_kind)
      return unless base_pounds && unit_price.to_d.positive? && (pricing == "per_pound" || quintal_pounds.to_i.positive?)

      self.quantity = pricing == "per_pound" ? base_pounds : (base_pounds / quintal_pounds).round(4)
      self.amount = (quantity * unit_price).round(2)
    end

    def output_weighed
      errors.add(:weight_side, :not_weighed) if weight_side == "output" && coffee_conversion && !coffee_conversion.finished?
    end

    def process_not_voided
      errors.add(:base, :voided) if coffee_conversion&.voided?
    end
end
