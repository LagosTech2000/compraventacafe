# Receipt given to a producer for one or more purchases, numbered
# correlatively. It is paid in one or more payments (InvoicePayment): with
# none it is pending, with some partial, and once they cover what it has to
# pay it is paid ("cancelada"). Status, payment date and method are kept on
# the invoice from its payments (#refresh_payment_status!).
class Invoice < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :trading

  PAYMENT_STATUSES = %w[pending partial paid].freeze
  UNPAID_STATUSES = %w[pending partial].freeze
  # Lists filter by a status, or by "unpaid": pending or partial.
  FILTER_STATUSES = [ "unpaid", *PAYMENT_STATUSES ].freeze
  PAYMENT_METHODS = %w[cash transfer check].freeze
  # Fixed key for the advisory lock that serializes invoice numbering.
  NUMBERING_LOCK_KEY = 7_301_001

  belongs_to :producer
  belongs_to :created_by, class_name: "User"
  has_many :purchases, dependent: :restrict_with_error
  has_many :loan_payments, through: :purchases
  has_many :payments, -> { in_order }, class_name: "InvoicePayment", dependent: :restrict_with_error, inverse_of: :invoice

  validates :issued_on, presence: true
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  # The method of its payments; empty while unpaid or when they used several.
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }, allow_nil: true
  validates :purchases, presence: true
  validate :purchases_belong_to_producer

  before_create :assign_number

  scope :newest_first, -> { order(number: :desc) }
  scope :pending, -> { where(payment_status: "pending") }
  scope :unpaid, -> { where(payment_status: UNPAID_STATUSES) }
  scope :with_payment_status, ->(status) { status == "unpaid" ? unpaid : where(payment_status: status) }

  def paid?
    payment_status == "paid"
  end

  def partial?
    payment_status == "partial"
  end

  def pending?
    payment_status == "pending"
  end

  def display_number
    format("%04d", number)
  end

  def audit_label
    "#{display_number} · #{producer.full_name}"
  end

  def gross_weight = purchases.sum(&:gross_weight)
  def net_weight = purchases.sum(&:net_weight)
  # QQ of the whole invoice: its net weight in quintals of 125 lb.
  def quintals = PurchaseCalculation.quintals(net_weight)
  # What damage took off the parchment purchases (cherry has none).
  def damage_weight = purchases.sum { |purchase| purchase.damage_weight || 0 }
  def damage_amount = purchases.sum { |purchase| purchase.damage_amount || 0 }
  def total = purchases.sum(&:total)
  # Loan payments made with these purchases are taken off what is paid.
  def loan_payments_total = purchases.sum(&:loan_payments_total)
  def amount_to_pay = total - loan_payments_total
  # Saved payments only: one being created is not paid yet.
  def paid_total = payments.reject(&:new_record?).sum(&:amount)
  def balance_due = amount_to_pay - paid_total

  # Pays what is left in one payment (demo data, tests).
  def mark_paid(method:, on:, user: created_by)
    payments.create(amount: balance_due, paid_on: on, payment_method: method, created_by: user).persisted?
  end

  # Status, date and method from the payments, against what it has to pay
  # now (loans paid with its purchases lower it). Read from the database:
  # the payments or loan payments that changed may not be loaded here.
  def refresh_payment_status!
    paid = payments.sum(:amount)
    status = if paid >= stored_amount_to_pay then "paid"
    elsif paid.positive? then "partial"
    else "pending"
    end
    methods = payments.unscope(:order).distinct.pluck(:payment_method)
    update!(payment_status: status, payment_method: (methods.first if methods.one?),
            paid_on: (status == "paid" ? (payments.maximum(:paid_on) || issued_on) : nil))
  end

  def human_payment_status
    self.class.human_attribute_name("payment_status/#{payment_status}")
  end

  # "Varias formas" when its payments used more than one.
  def human_payment_method
    return self.class.human_attribute_name("payment_method/#{payment_method}") if payment_method

    I18n.t("trading.invoices.mixed_payment_methods") if payments.many?
  end

  private
    def stored_amount_to_pay
      purchase_ids = purchases.select(:id)
      Purchase.where(id: purchase_ids).sum(:total) - LoanPayment.where(purchase_id: purchase_ids).sum(:amount)
    end

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
