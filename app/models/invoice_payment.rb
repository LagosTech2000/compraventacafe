# A payment of an invoice to its producer ("abono"). An invoice is paid in
# one or more of them: while they do not cover what it has to pay it is
# "partial", and once they do it is "paid" (Invoice#refresh_payment_status!).
# Payments are never edited; only the latest one can be removed.
class InvoicePayment < ApplicationRecord
  include Auditable
  include HasMoneyAccount
  include LiveUpdates
  live_updates :trading

  belongs_to :invoice
  belongs_to :created_by, class_name: "User"

  validates :amount, numericality: { greater_than: 0, less_than: 100_000_000 }
  validates :paid_on, presence: true
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validate :within_balance, on: :create
  validate :not_before_invoice, :not_before_last_payment, on: :create

  after_create :refresh_invoice
  after_destroy :refresh_invoice

  scope :in_order, -> { order(:paid_on, :id) }

  def display_number
    format("%04d", id)
  end

  def audit_label
    "#{display_number} · #{I18n.t("trading.invoices.show.invoice")} #{invoice.display_number}"
  end

  def human_payment_method
    Invoice.human_attribute_name("payment_method/#{payment_method}")
  end

  def latest?
    invoice.payments.in_order.last == self
  end

  # What the invoice still had to pay after this payment.
  def balance_after
    paid_until = invoice.payments.select { |payment| ([ payment.paid_on, payment.id ] <=> [ paid_on, id ]) <= 0 }.sum(&:amount)
    invoice.amount_to_pay - paid_until
  end

  private
    def within_balance
      return unless invoice && amount.to_d.positive?

      balance = invoice.balance_due
      errors.add(:amount, :over_balance, balance: ActiveSupport::NumberHelper.number_to_currency(balance)) if amount > balance
    end

    def not_before_invoice
      errors.add(:paid_on, :before_invoice) if invoice && paid_on && paid_on < invoice.issued_on
    end

    # In date order, like the loan payments: a payment never goes before the last one.
    def not_before_last_payment
      last = invoice&.payments&.maximum(:paid_on)
      errors.add(:paid_on, :before_last_payment) if last && paid_on && paid_on < last
    end

    def refresh_invoice
      invoice.refresh_payment_status!
    end
end
