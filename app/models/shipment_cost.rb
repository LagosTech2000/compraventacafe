# What a shipment cost besides its coffee (Fernando, 2026-11-12), registered
# from it as a process's costs (ProcessingCost): flete, mano de obra, carga
# y descarga, combustible u otro; an agreed total, or per pound or quintal
# of a weight of the shipment (the local scale or the buyer's, gross or
# net, quintals of 100, 120 or 125 lb). The basis, quantity and amount are
# kept. It goes out of an account (optional, Consolidación gives one later)
# and shows in Control financiero's movements. Registered or removed.
class ShipmentCost < ApplicationRecord
  include Auditable
  include OwnedRecord
  include HasMoneyAccount
  include LiveUpdates
  # The photo or PDF of its receipt, optional (Fernando, 2026-11-16).
  include HasReceipt
  live_updates :sales, :finance

  # The ones of the processes that apply to a trip (pending confirmation).
  CONCEPTS = %w[freight labor loading fuel other].freeze
  PRICINGS = ProcessingCost::PRICINGS
  WEIGHT_SIDES = Shipment::SIDES
  WEIGHT_KINDS = ProcessingCost::WEIGHT_KINDS
  QUINTAL_POUNDS = ProcessingCost::QUINTAL_POUNDS
  MAX_AMOUNT = ProcessingCost::MAX_AMOUNT

  belongs_to :shipment
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
  validate :destination_weighed, unless: :total?
  validate :shipment_active, on: :create

  scope :chronological, -> { order(:paid_on, :id) }

  def total? = pricing == "total"
  def per_quintal? = pricing == "per_quintal"

  def human_concept = self.class.human_attribute_name("concept/#{concept}")
  def label = [ human_concept, description ].compact.join(" · ")
  def audit_label = "#{label} · #{shipment&.audit_label}"

  # The pounds a cost per unit is charged on.
  def self.base_pounds(shipment, side, kind)
    return unless shipment && side.in?(WEIGHT_SIDES) && kind.in?(WEIGHT_KINDS)

    kind == "net" ? shipment["#{side}_net_weight"] : shipment["#{side}_gross_weight"]
  end

  private
    def calculate
      if total?
        self.weight_side = self.weight_kind = self.quintal_pounds = self.base_pounds = self.quantity = self.unit_price = nil
        return
      end

      self.quintal_pounds = nil unless per_quintal?
      self.base_pounds = self.class.base_pounds(shipment, weight_side, weight_kind)
      return unless base_pounds && unit_price.to_d.positive? && (pricing == "per_pound" || quintal_pounds.to_i.positive?)

      self.quantity = pricing == "per_pound" ? base_pounds : (base_pounds / quintal_pounds).round(4)
      self.amount = (quantity * unit_price).round(2)
    end

    def destination_weighed
      errors.add(:weight_side, :not_weighed) if weight_side == "destination" && shipment && !shipment.received?
    end

    def shipment_active
      errors.add(:base, :voided) if shipment&.voided?
    end
end
