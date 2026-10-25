# A payment the buyer makes on a sale ("cobro", Fernando, 2026-10-23), like
# an invoice's payments: never over what is owed, in date order, never
# before the sale; never edited and only the latest one can be removed.
# Each has its printable receipt (original and copy).
#
# A collection «con anticipo» (ADVANCE, Fernando, 2026-10-25) takes off
# the buyer's advances (BuyerAdvance), never more than their balance: it
# moves no money (the money came in with the advance), so it has no
# account and stays out of the ledger and the balances.
class SalePayment < ApplicationRecord
  include Auditable
  include HasMoneyAccount
  include LiveUpdates
  live_updates :sales

  ADVANCE = "advance".freeze
  METHODS = (Invoice::PAYMENT_METHODS + [ ADVANCE ]).freeze

  belongs_to :sale, inverse_of: :payments
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :amount, numericality: { greater_than: 0, less_than: 100_000_000 }
  validates :paid_on, presence: true
  validates :payment_method, inclusion: { in: METHODS }
  validates :observations, length: { maximum: 500 }
  validate :sale_active, :within_balance, :not_before_sale, :not_before_last_payment, on: :create
  validate :within_advances, on: :create, if: :advance?

  # An advance moves no money: no account.
  before_validation { self.money_account_id = nil if advance? }

  after_create :refresh_sale
  after_destroy :refresh_sale

  scope :in_order, -> { order(:paid_on, :id) }
  scope :advance, -> { where(payment_method: ADVANCE) }
  # The ones that moved money (into an account).
  scope :in_money, -> { where.not(payment_method: ADVANCE) }
  scope :newest_first, -> { order(paid_on: :desc, id: :desc) }

  def display_number = format("%04d", id)

  def audit_label = "#{display_number} · #{I18n.t("sales.sales.show.title", number: sale&.display_number)}"

  def advance? = payment_method == ADVANCE
  def human_payment_method = self.class.human_method(payment_method)
  def self.human_method(method) = human_attribute_name("payment_method/#{method}")

  def latest? = sale.payments.in_order.last == self

  # What the sale still owed after this payment.
  def balance_after
    paid_until = sale.payments.select { |payment| ([ payment.paid_on, payment.id ] <=> [ paid_on, id ]) <= 0 }.sum(&:amount)
    sale.total - paid_until
  end

  private
    def sale_active
      errors.add(:base, :sale_voided) if sale&.voided?
    end

    def within_balance
      return unless sale && amount.to_d.positive?

      balance = sale.balance_due
      errors.add(:amount, :over_balance, balance: ActiveSupport::NumberHelper.number_to_currency(balance)) if amount > balance
    end

    def within_advances
      return unless sale && amount.to_d.positive?

      balance = sale.buyer.advance_balance
      errors.add(:amount, :over_advances, balance: ActiveSupport::NumberHelper.number_to_currency(balance)) if amount > balance
    end

    def not_before_sale
      errors.add(:paid_on, :before_sale) if sale && paid_on && paid_on < sale.sold_on
    end

    def not_before_last_payment
      last = sale&.payments&.maximum(:paid_on)
      errors.add(:paid_on, :before_last_payment) if last && paid_on && paid_on < last
    end

    def refresh_sale
      sale.refresh_payment_status!
    end
end
