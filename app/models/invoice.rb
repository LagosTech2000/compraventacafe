# Receipt given to a producer for one or more purchases. It is marked as
# paid ("cancelada") or pending, and numbered correlatively.
class Invoice < ApplicationRecord
  include Auditable

  PAYMENT_STATUSES = %w[pending paid].freeze
  PAYMENT_METHODS = %w[cash transfer check].freeze
  # Fixed key for the advisory lock that serializes invoice numbering.
  NUMBERING_LOCK_KEY = 7_301_001

  belongs_to :producer
  belongs_to :created_by, class_name: "User"
  has_many :purchases, dependent: :restrict_with_error

  validates :issued_on, presence: true
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }, if: :paid?
  validates :paid_on, presence: true, if: :paid?
  validates :purchases, presence: true
  validate :purchases_belong_to_producer

  before_create :assign_number

  scope :newest_first, -> { order(number: :desc) }
  scope :pending, -> { where(payment_status: "pending") }

  def paid?
    payment_status == "paid"
  end

  def display_number
    format("%04d", number)
  end

  def audit_label
    "#{display_number} · #{producer.full_name}"
  end

  def gross_weight = purchases.sum(&:gross_weight)
  def net_weight = purchases.sum(&:net_weight)
  def total = purchases.sum(&:total)

  def mark_paid(method:, on:)
    update(payment_status: "paid", payment_method: method, paid_on: on)
  end

  def human_payment_status
    self.class.human_attribute_name("payment_status/#{payment_status}")
  end

  def human_payment_method
    payment_method && self.class.human_attribute_name("payment_method/#{payment_method}")
  end

  private
    # Correlative numbers without gaps from concurrent saves: a transaction
    # lock serializes numbering; the unique index is the last safety net.
    def assign_number
      self.class.connection.execute("SELECT pg_advisory_xact_lock(#{NUMBERING_LOCK_KEY})")
      self.number = (self.class.maximum(:number) || 0) + 1
    end

    def purchases_belong_to_producer
      return if purchases.all? { |purchase| purchase.producer_id == producer_id }

      errors.add(:purchases, :other_producer)
    end
end
