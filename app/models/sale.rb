# A sale of coffee to a buyer (Fernando, 2026-10-23): shipments of that
# buyer already weighed at destination (SaleLine), charged on the buyer's
# net weight, by the pound or by the quintal (120 lb unless the sale says
# otherwise, quintal_pounds). Made with
# SaleIssuer; weights and total are kept as they were then.
#
# Collected in payments (SalePayment), like the invoices: pending, partial,
# paid. The buyer's settlement (buyer_total, with its reason) is what the
# buyer says it pays per its own liquidation; once entered, it is what is
# collected (amount_due) instead of the total. It is not edited: voided (only without payments) its shipments are
# free for another sale, and its lines stay as a record.
class Sale < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  NUMBERING_LOCK_KEY = 7_301_003
  PRICE_UNITS = %w[pound quintal].freeze
  # A sale's quintal: 120 lb by default, editable per sale (Fernando,
  # 2026-10-25; it was a fixed 100 lb). Each sale keeps its own.
  QUINTAL_POUNDS = 120
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

  normalizes :buyer_document_number, :void_reason, :buyer_total_reason, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :sold_on, presence: true
  validates :coffee_state, inclusion: { in: Purchase::COFFEE_STATES }
  validates :price_unit, inclusion: { in: PRICE_UNITS }
  validates :unit_price, numericality: { greater_than: 0, less_than: 10_000_000 }
  validates :quintal_pounds, numericality: { greater_than: 0, less_than: 1_000 }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  validates :payment_method, inclusion: { in: SalePayment::METHODS }, allow_nil: true
  validates :buyer_document_number, length: { maximum: 60 }
  validates :void_reason, length: { maximum: 200 }
  validates :observations, length: { maximum: 500 }
  validates :buyer_total, numericality: { greater_than: 0, less_than: 1_000_000_000 }, allow_nil: true
  validates :buyer_total_reason, length: { maximum: 200 }
  validates :buyer_total_reason, presence: true, if: -> { buyer_total.present? && buyer_total != total }
  validate :buyer_total_covers_payments, if: :buyer_total_changed?
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
  # of `quintal_pounds`.
  def self.amount_for(net_weight, unit_price:, price_unit:, quintal_pounds: QUINTAL_POUNDS)
    pounds = BigDecimal(net_weight.to_s)
    price = BigDecimal(unit_price.to_s)
    (price_unit == "quintal" ? pounds / BigDecimal(quintal_pounds.to_s) * price : pounds * price).round(2)
  end

  def display_number = format("%04d", number)
  def audit_label = "#{display_number} · #{buyer&.name}"

  def voided? = voided_at.present?
  def paid? = payment_status == "paid"
  def partial? = payment_status == "partial"
  def pending? = payment_status == "pending"

  # Quintals of the sale, of its own pounds.
  def quintals = (net_weight / quintal_pounds).round(2)

  # The price of one pound: what a sum of money is worth in coffee.
  def price_per_pound = price_unit == "quintal" ? unit_price / quintal_pounds : unit_price

  # The buyer's gross weight of its shipments (destination scale): from the
  # lines already loaded with their shipments, or in one query.
  def gross_weight
    return lines.sum { |line| line.shipment.destination_gross_weight.to_d } if lines.loaded? && lines.all? { it.association(:shipment).loaded? }

    lines.joins(:shipment).sum("shipments.destination_gross_weight")
  end

  # The coffee a sum of money stands for at the sale's price: net pounds,
  # and gross pounds in the sale's own gross-to-net proportion.
  def pounds_for(amount)
    net = price_per_pound.positive? ? (amount.to_d / price_per_pound).round(2) : 0
    gross = net_weight.positive? ? (net * gross_weight / net_weight).round(2) : 0
    { net:, gross: }
  end
  # The buyer's net − the local net, over its shipments.
  def net_difference = net_weight - origin_net_weight
  def difference_percent = origin_net_weight.positive? ? (net_difference * 100 / origin_net_weight).round(2) : nil
  # That difference in money, at the sale's price per pound (Fernando,
  # 2026-10-25): below zero, coffee that left and was not charged for.
  def difference_amount = (net_difference * price_per_pound).round(2)

  def over_tolerance?(tolerance = WeightTolerance.percent)
    tolerance.present? && difference_percent.present? && difference_percent.abs > tolerance
  end

  # What is collected: the buyer's settlement when entered, else the total.
  def amount_due = buyer_total || total
  # The buyer's settlement − the sale's total (below zero: it pays less).
  def settlement_difference = buyer_total && (buyer_total - total)

  def paid_total = payments.reject(&:new_record?).sum(&:amount)
  def balance_due = voided? ? 0 : amount_due - paid_total

  def human_payment_status = self.class.human_attribute_name("payment_status/#{payment_status}")
  # "Por quintal de 120 lb" or "Por libra".
  def human_price_unit
    return self.class.human_attribute_name("price_unit/pound") unless price_unit == "quintal"

    I18n.t("sales.sales.price_unit_quintal", pounds: quintal_pounds_label)
  end

  # Its pounds per quintal as they read: "120", "112.5".
  def quintal_pounds_label = ActiveSupport::NumberHelper.number_to_rounded(quintal_pounds, precision: 2, strip_insignificant_zeros: true)

  # "Equivale a … lb netas y … lb brutas", for a collection «con anticipo».
  def advance_pounds_text(amount)
    pounds = pounds_for(amount)
    I18n.t("sales.sales.advance_pounds", net: ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", pounds[:net])),
                                         gross: ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", pounds[:gross])))
  end
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
    status = if paid >= amount_due then "paid"
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

  # Enters (or clears, with nil) the buyer's settlement and refreshes the status.
  def settle!(buyer_total:, reason:)
    transaction do
      lock!
      update!(buyer_total:, buyer_total_reason: reason)
      refresh_payment_status!
    end
  end

  private
    def buyer_total_covers_payments
      return unless buyer_total

      paid = payments.sum(:amount)
      errors.add(:buyer_total, :below_paid, paid: ActiveSupport::NumberHelper.number_to_currency(paid)) if buyer_total < paid
    end

    def assign_number
      self.class.connection.execute("SELECT pg_advisory_xact_lock(#{NUMBERING_LOCK_KEY})")
      self.number = (self.class.maximum(:number) || 0) + 1
    end
end
