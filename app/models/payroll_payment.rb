# The payment of one pay period of a payroll: one line per member with what
# they earned, what went to their loans and what they were handed. Created
# by PayrollPaymentIssuer. It can only be removed while it is the latest
# payment of the payroll and its loan payments are the latest of their loans.
class PayrollPayment < ApplicationRecord
  include Auditable

  belongs_to :payroll
  belongs_to :created_by, class_name: "User"
  has_many :lines, class_name: "PayrollPaymentLine", dependent: :destroy, inverse_of: :payment
  has_many :loan_payments, through: :lines

  normalizes :observations, with: FieldFormats::STRIP

  validates :period_starts_on, :period_ends_on, :paid_on, presence: true
  validates :period_starts_on, uniqueness: { scope: :payroll_id }
  validates :observations, length: { maximum: 500 }

  scope :newest_first, -> { order(period_starts_on: :desc, id: :desc) }

  def audit_label
    "#{payroll&.audit_label} · #{I18n.l(period_starts_on)}–#{I18n.l(period_ends_on)}"
  end

  def period = PayPeriod.new(period_starts_on, period_ends_on)

  def latest?
    payroll.payments.maximum(:period_starts_on) == period_starts_on
  end

  def removable?
    latest? && loan_payments.all?(&:latest?)
  end

  # Removes its loan payments with it (they reopen the loans they paid off).
  def remove!
    transaction do
      loan_payments.each(&:destroy!)
      destroy!
    end
  end
end
