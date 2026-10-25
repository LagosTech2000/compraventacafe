# A sale of coffee to a buyer (Fernando, 2026-10-23): shipments of that
# buyer already weighed at destination (SaleLine), charged on the buyer's
# net weight, by the pound or by the quintal of 100 lb. Made with
# SaleIssuer; weights and total are kept as they were then.
#
# Collected in payments (SalePayment), like the invoices: pending, partial,
# paid. It is not edited: voided (only without payments) its shipments are
# free for another sale, and its lines stay as a record.
class Sale < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  NUMBERING_LOCK_KEY = 7_301_003
  PRICE_UNITS = %w[pound quintal].freeze
  # A sale's quintal (Fernando, 2026-10-23), as in the client's contracts.
  QUINTAL_POUNDS = 100
  PAYMENT_STATUSES = Invoice::PAYMENT_STATUSES
  UNPAID_STATUSES = Invoice::UNPAID_STATUSES
  FILTER_STATUSES = [ "unpaid", *PAYMENT_STATUSES, "voided" ].freeze

  belongs_to :buyer
  belongs_to :created_by, class_name: "User"
  belongs_to :voided_by, class_name: "User", optional: true
  has_many :lines, -> { order(:id) }, class_name: "SaleLine", dependent: :restrict_with_error, inverse_of: :sale
  has_many :shipments, through: :lines
  # Saved on their own (SalePayment validates itself): one being typed never
  # stops the sale from refreshing its status.
  has_many :payments, -> { in_order }, class_name: "SalePayment", dependent: :restrict_with_error, inverse_of: :sale, validate: false

  normalizes :buyer_document_number, :void_reason, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :sold_on, presence: true
  validates :coffee_state, inclusion: { in: Purchase::COFFEE_STATES }
  validates :price_unit, inclusion: { in: PRICE_UNITS }
  validates :unit_price, numericality: { greater_than: 0, less_than: 10_000_000 }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  validates :payment_method, inclusion: { in: SalePayment::METHODS }, allow_nil: true
  validates :buyer_document_number, length: { maximum: 60 }
  validates :void_reason, length: { maximum: 200 }
  validates :observations, length: { maximum: 500 }
  validates :lines, presence: true, on: :create

  before_create :assign_number

  scope :active, -> { where(voided_at: nil) }
  scope :voided, -> { where.not(voided_at: nil) }
  scope :unpaid, -> { active.where(payment_status: UNPAID_STATUSES) }
  scope :newest_first, -> { order(number: :desc) }
  scope :in_season, ->(season) { where(sold_on: season.starts_on..season.ends_on) }

  def self.with_payment_status(status)
    case status
    when "unpaid" then unpaid
    when "voided" then voided
    when *PAYMENT_STATUSES then active.where(payment_status: status)
    else all
    end
  end

  # The amount of a net weight at a price: by the pound, or by the quintal
  # of 100 lb.
  def self.amount_for(net_weight, unit_price:, price_unit:)
    pounds = BigDecimal(net_weight.to_s)
    price = BigDecimal(unit_price.to_s)
    (price_unit == "quintal" ? pounds / QUINTAL_POUNDS * price : pounds * price).round(2)
  end

  def display_number = format("%04d", number)
  def audit_label = "#{display_number} · #{buyer&.name}"

  def voided? = voided_at.present?
  def paid? = payment_status == "paid"
  def partial? = payment_status == "partial"
  def pending? = payment_status == "pending"

  # Quintals of the sale (100 lb).
  def quintals = (net_weight / QUINTAL_POUNDS).round(2)
  # The buyer's net − the local net, over its shipments.
  def net_difference = net_weight - origin_net_weight
  def difference_percent = origin_net_weight.positive? ? (net_difference * 100 / origin_net_weight).round(2) : nil

  def over_tolerance?(tolerance = WeightTolerance.percent)
    tolerance.present? && difference_percent.present? && difference_percent.abs > tolerance
  end

  def paid_total = payments.reject(&:new_record?).sum(&:amount)
  def balance_due = voided? ? 0 : total - paid_total

  def human_payment_status = self.class.human_attribute_name("payment_status/#{payment_status}")
  def human_price_unit = self.class.human_attribute_name("price_unit/#{price_unit}")
  def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")

  # "Varias formas" when its payments used more than one.
  def human_payment_method
    return SalePayment.human_method(payment_method) if payment_method

    I18n.t("trading.invoices.mixed_payment_methods") if payments.many?
  end

  # Where it stands: voided, or its payment status.
  def state = voided? ? "voided" : payment_status

  def voidable? = !voided? && payments.none?

  # Status, date and method from the payments (read from the database).
  def refresh_payment_status!
    paid = payments.sum(:amount)
    status = if paid >= total then "paid"
    elsif paid.positive? then "partial"
    else "pending"
    end
    methods = payments.unscope(:order).distinct.pluck(:payment_method)
    update!(payment_status: status, payment_method: (methods.first if methods.one?),
            paid_on: (status == "paid" ? (payments.maximum(:paid_on) || sold_on) : nil))
  end

  # Voids it and frees its shipments for another sale. Only without payments.
  def void!(user, reason: nil)
    transaction do
      lock!
      unless voidable?
        errors.add(:base, :has_payments)
        raise ActiveRecord::RecordInvalid, self
      end

      lines.each { |line| line.update!(active: false) }
      update!(voided_at: Time.current, voided_by: user, void_reason: reason)
    end
  end

  private
    def assign_number
      self.class.connection.execute("SELECT pg_advisory_xact_lock(#{NUMBERING_LOCK_KEY})")
      self.number = (self.class.maximum(:number) || 0) + 1
    end
end
