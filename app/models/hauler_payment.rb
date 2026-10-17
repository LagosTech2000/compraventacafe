# A payment of a hauler's commissions (Fernando, 2026-10-16): on what they
# are owed, never more; each with its printable receipt (original and copy).
# Payments are never edited and, like the other payments, they go in date
# order and only the latest one can be removed. Its balance after is kept,
# so the receipt prints the same later.
class HaulerPayment < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :trading

  belongs_to :hauler
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :amount, numericality: { greater_than: 0, less_than: 100_000_000 }
  validates :paid_on, presence: true
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validates :observations, length: { maximum: 500 }
  validate :within_balance, :not_before_last_payment, on: :create

  before_create { self.balance_after = hauler.balance - amount }

  scope :in_order, -> { order(:paid_on, :id) }
  scope :newest_first, -> { order(paid_on: :desc, id: :desc) }

  def display_number = format("%04d", id)

  def audit_label
    "#{display_number} · #{hauler&.full_name}"
  end

  def human_payment_method
    Invoice.human_attribute_name("payment_method/#{payment_method}")
  end

  def latest?
    hauler.payments.in_order.last == self
  end

  private
    def within_balance
      return unless hauler && amount.to_d.positive?

      balance = hauler.balance
      errors.add(:amount, :over_balance, balance: ActiveSupport::NumberHelper.number_to_currency(balance)) if amount > balance
    end

    def not_before_last_payment
      last = hauler&.payments&.maximum(:paid_on)
      errors.add(:paid_on, :before_last_payment) if last && paid_on && paid_on < last
    end
end
