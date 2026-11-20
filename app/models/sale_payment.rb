# A payment the buyer makes on a sale ("cobro", Fernando, 2026-10-23), like
# an invoice's payments: never over what is owed, in date order, never
# before the sale; not edited, by anyone, and only the latest one can be
# removed (Fernando, 2026-11-18). Only its account changes (Consolidación).
# Each has its printable receipt (original and copy).
#
# A collection «con anticipo» (ADVANCE, Fernando, 2026-10-25) is made only
# by applying an advance to the sale (BuyerAdvanceSale, Fernando,
# 2026-11-16), which holds it: it moves no money (the money came in with
# the advance), so it has no account and stays out of the ledger and the
# balances. Removing it removes its application.
class SalePayment < ApplicationRecord
  include Auditable
  include OwnedRecord
  include HasMoneyAccount
  include LiveUpdates
  live_updates :sales

  ADVANCE = "advance".freeze
  METHODS = (Invoice::PAYMENT_METHODS + [ ADVANCE ]).freeze

  belongs_to :sale, inverse_of: :payments
  belongs_to :buyer_advance_sale, optional: true, inverse_of: :payment
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :amount, numericality: { greater_than: 0, less_than: 100_000_000 }
  validates :paid_on, presence: true
  validates :paid_on, not_in_future: true
  validates :payment_method, inclusion: { in: METHODS }
  validates :observations, length: { maximum: 500 }
  validate :sale_active, :within_balance, :not_before_sale, :not_before_last_payment, on: :create
  validate :from_an_application, if: :advance?
  validate :unchanged, on: :update

  # An advance moves no money: no account.
  before_validation { self.money_account_id = nil if advance? }

  after_create :refresh_sale
  after_update :refresh_sale
  after_destroy :refresh_sale
  # Removed on its own (from the sale): its application goes with it.
  after_destroy { buyer_advance_sale.destroy! if buyer_advance_sale && !destroyed_by_association }

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
    sale.amount_due - paid_until
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

    # What was collected stays as it was collected.
    def unchanged
      errors.add(:base, :closed) if (changed & %w[amount paid_on payment_method sale_id]).any?
    end

    # Only an advance applied to the sale collects «con anticipo», and its
    # amount is the application's.
    def from_an_application
      errors.add(:payment_method, :advance_only_applied) if buyer_advance_sale.nil? || amount != buyer_advance_sale.amount
    end

    def not_before_sale
      errors.add(:paid_on, :before_sale) if sale && paid_on && paid_on < sale.sold_on
    end

    def not_before_last_payment
      last = sale&.payments&.maximum(:paid_on)
      errors.add(:paid_on, :before_last_payment) if last && paid_on && paid_on < last
    end

    def refresh_sale
      sale.refresh_payment_status! unless sale.voided?
    end
end
