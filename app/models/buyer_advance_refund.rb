# Part of an advance given back in money (Fernando, 2026-11-16: an advance
# is cancelled with sales, with money or both): it goes out of an account
# (MoneyMovements «buyer_advance_refunds», AccountBalance), never over what
# the advance has left, never before it. Registered or removed (the
# latest only), never edited.
class BuyerAdvanceRefund < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  include DayLock
  locks_day :refunded_on
  live_updates :sales, :finance

  belongs_to :buyer_advance, inverse_of: :refunds
  belongs_to :money_account
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :refunded_on, presence: true
  validates :amount, numericality: { greater_than: 0, less_than: 100_000_000 }
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validates :observations, length: { maximum: 500 }
  validate :within_advance, :not_before_advance, on: :create
  validate { errors.add(:money_account, :inactive) if will_save_change_to_money_account_id? && money_account && !money_account.active? }

  after_commit :refresh_advance

  scope :in_order, -> { order(:refunded_on, :id) }

  def display_number = format("%04d", id)
  def audit_label = "#{self.class.model_name.human} #{display_number} · #{buyer_advance&.audit_label}"
  def human_payment_method = Invoice.human_attribute_name("payment_method/#{payment_method}")
  def latest? = buyer_advance.refunds.in_order.last == self

  private
    def within_advance
      return unless buyer_advance && amount.to_d.positive?

      balance = buyer_advance.balance
      errors.add(:amount, :over_advance, balance: ActiveSupport::NumberHelper.number_to_currency(balance)) if amount > balance
    end

    def not_before_advance
      errors.add(:refunded_on, :before_advance) if buyer_advance && refunded_on && refunded_on < buyer_advance.received_on
    end

    def refresh_advance
      BuyerAdvance.find_by(id: buyer_advance_id)&.refresh_status!
    end
end
