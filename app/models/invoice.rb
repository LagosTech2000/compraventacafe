# Receipt given to a producer for one or more purchases, numbered
# correlatively. It is paid in one or more payments (InvoicePayment): with
# none it is pending, with some partial, and once they cover what it has to
# pay it is paid ("cancelada"). Status, payment date and method are kept on
# the invoice from its payments (#refresh_payment_status!).
#
# Never edited, by anyone (Fernando, 2026-11-18: «que no se pueda editar
# facturas ya canceladas»). An administrator voids it, with a reason, once
# nothing after it depends on it: no payments (removed first, the latest
# one first), no purchase that paid a loan and no lot that took it gone to
# a shipment or a process. Voiding voids its purchases too (their coffee
# leaves the stock); it keeps its number and stays as a record, out of
# every list and total. One edited before (2026-11-12 to 2026-11-18) may
# show as overpaid (#overpaid_amount).
class Invoice < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  include DayLock
  locks_day :issued_on, free: %w[payment_status payment_method paid_on producer_id]
  live_updates :trading

  PAYMENT_STATUSES = %w[pending partial paid].freeze
  UNPAID_STATUSES = %w[pending partial].freeze
  # Lists filter by a status, or by "unpaid": pending or partial.
  FILTER_STATUSES = [ "unpaid", *PAYMENT_STATUSES ].freeze
  # The invoices' lists also show the voided ones, when asked for (Fernando,
  # 2026-11-12), or every state, voided too («all», Fernando, 2026-11-13).
  LIST_STATUSES = [ *FILTER_STATUSES, "voided", "all" ].freeze
  PAYMENT_METHODS = %w[cash transfer check].freeze
  # Fixed key for the advisory lock that serializes invoice numbering.
  NUMBERING_LOCK_KEY = 7_301_001

  belongs_to :producer
  belongs_to :created_by, class_name: "User"
  belongs_to :voided_by, class_name: "User", optional: true
  has_many :purchases, dependent: :restrict_with_error
  # The lots that took a share of its coffee (Fernando, 2026-11-13).
  has_many :batch_invoices, class_name: "CoffeeBatchInvoice", dependent: :restrict_with_error
  has_many :coffee_batches, through: :batch_invoices
  has_many :loan_payments, through: :purchases
  has_many :payments, -> { in_order }, class_name: "InvoicePayment", dependent: :restrict_with_error, inverse_of: :invoice

  normalizes :void_reason, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :issued_on, presence: true
  validates :issued_on, not_in_future: true
  validates :void_reason, length: { maximum: 200 }
  validates :observations, length: { maximum: 500 }
  validate :not_after_payments, if: -> { persisted? && will_save_change_to_issued_on? }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  # The method of its payments; empty while unpaid or when they used several.
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }, allow_nil: true
  validates :purchases, presence: true
  validate :purchases_belong_to_producer

  before_create :assign_number

  scope :newest_first, -> { order(number: :desc) }
  scope :active, -> { where(voided_at: nil) }
  scope :voided, -> { where.not(voided_at: nil) }
  scope :pending, -> { active.where(payment_status: "pending") }
  scope :unpaid, -> { active.where(payment_status: UNPAID_STATUSES) }

  def self.with_payment_status(status)
    case status
    when "unpaid" then unpaid
    when "voided" then voided
    when *PAYMENT_STATUSES then active.where(payment_status: status)
    when "all" then all
    else active
    end
  end
  # Every purchase of the invoice in that coffee state (a shipment's invoices).
  scope :of_coffee_state, lambda { |state|
    where(id: Purchase.select(:invoice_id).where(coffee_state: state))
      .where.not(id: Purchase.select(:invoice_id).where.not(coffee_state: state).where.not(invoice_id: nil))
  }

  def paid?
    payment_status == "paid"
  end

  def voided? = voided_at.present?
  # Where it stands: voided, or its payment status.
  def state = voided? ? "voided" : payment_status

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
  def total = purchases.sum(&:total)
  # Loan payments made with these purchases are taken off what is paid.
  def loan_payments_total = purchases.sum(&:loan_payments_total)
  def amount_to_pay = total - loan_payments_total
  # Saved payments only: one being created is not paid yet.
  def paid_total = payments.reject(&:new_record?).sum(&:amount)
  def balance_due = voided? ? 0 : [ amount_to_pay - paid_total, 0 ].max
  # Paid over what it has to pay now (its total was lowered by an edit).
  def overpaid_amount = voided? ? 0 : [ paid_total - amount_to_pay, 0 ].max
  def overpaid? = overpaid_amount.positive?

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
    self.class.human_attribute_name("payment_status/#{state}")
  end

  # Voids it with its purchases (Fernando, 2026-11-12). Only once nothing
  # after it depends on it (Fernando, 2026-11-18): no payments, no purchase
  # that paid a loan, no lot of it gone to a shipment or a process; nor if
  # voiding a purchase leaves a hauler owing what was paid. Its share of
  # lots still free leaves them. All of it or nothing.
  def void!(user, reason:)
    transaction do
      lock!
      errors.add(:base, :already_voided) if voided?
      errors.add(:void_reason, :blank) if reason.to_s.squish.empty?
      void_blockers.each { |key, options| errors.add(:base, key, **options) }
      raise ActiveRecord::RecordInvalid, self if errors.any?

      batch_invoices.each(&:destroy!)
      update!(voided_at: Time.current, voided_by: user, void_reason: reason)
      purchases.each do |purchase|
        purchase.invoice = self
        purchase.void!(user)
      rescue ActiveRecord::RecordInvalid => error
        error.record.errors.full_messages.each { errors.add(:base, :purchase_not_voided, number: purchase.id, message: it) }
        raise ActiveRecord::RecordInvalid, self
      end
    end
  end

  # What has to be undone before voiding it (Fernando, 2026-11-18):
  # [[error key, options]]; empty when it can be voided.
  def void_blockers
    blockers = []
    blockers << [ :has_payments, { count: payments.count } ] if payments.exists?
    blockers << [ :has_loan_payments, {} ] if LoanPayment.where(purchase_id: purchases.select(:id)).exists?
    coffee_batches.includes(:shipment, :processing).select(&:taken?).each do |batch|
      taker = if batch.shipment then I18n.t("sales.coffee_batches.taker.shipment", number: batch.shipment.display_number)
      else I18n.t("sales.coffee_batches.taker.process", number: batch.processing.display_number)
      end
      blockers << [ :lot_taken, { batch: batch.label, taker: } ]
    end
    blockers
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

    # Its payments were made on or after its date.
    def not_after_payments
      first = payments.minimum(:paid_on)
      errors.add(:issued_on, :after_payments, date: I18n.l(first)) if first && issued_on && issued_on > first
    end

    def purchases_belong_to_producer
      return if purchases.all? { |purchase| purchase.producer_id == producer_id }

      errors.add(:purchases, :other_producer)
    end
end
