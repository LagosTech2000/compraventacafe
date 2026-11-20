# An advance a buyer or a bank gives the business, paid back with coffee,
# without interest (Fernando, 2026-10-25). The money comes into an account
# on its day (MoneyMovements: buyer_advances). Registered without a sale
# (Fernando, 2026-11-16) and applied later to one or several sales by a %
# of it (BuyerAdvanceSale, each a collection «con anticipo»), or given back
# in money (BuyerAdvanceRefund): «pendiente» while something is left,
# «cancelado» when that covers it all. Never edited; removed only while
# nothing was applied or given back.
class BuyerAdvance < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  include DayLock
  locks_day :received_on, free: %w[status cancelled_on buyer_id]
  live_updates :sales

  belongs_to :buyer
  belongs_to :money_account
  belongs_to :created_by, class_name: "User"
  has_many :applications, -> { order(:applied_on, :id) }, class_name: "BuyerAdvanceSale", dependent: :restrict_with_error, inverse_of: :buyer_advance
  has_many :refunds, -> { order(:refunded_on, :id) }, class_name: "BuyerAdvanceRefund", dependent: :restrict_with_error, inverse_of: :buyer_advance

  STATUSES = %w[pending cancelled].freeze
  # What is left of each advance, in SQL (lists, totals, the buyer's balance).
  APPLIED_SQL = "COALESCE((SELECT SUM(buyer_advance_sales.amount) FROM buyer_advance_sales " \
                "WHERE buyer_advance_sales.buyer_advance_id = buyer_advances.id), 0)".freeze
  REFUNDED_SQL = "COALESCE((SELECT SUM(buyer_advance_refunds.amount) FROM buyer_advance_refunds " \
                 "WHERE buyer_advance_refunds.buyer_advance_id = buyer_advances.id), 0)".freeze
  BALANCE_SQL = "(buyer_advances.amount - #{APPLIED_SQL} - #{REFUNDED_SQL})".freeze

  normalizes :document_number, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :received_on, presence: true
  validates :amount, numericality: { greater_than: 0, less_than: 100_000_000 }
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validates :document_number, length: { maximum: 60 }
  validates :observations, length: { maximum: 500 }
  validate :money_account_active, if: :will_save_change_to_money_account_id?

  before_destroy :ensure_not_used, prepend: true

  scope :newest_first, -> { order(received_on: :desc, id: :desc) }
  scope :pending, -> { where(status: "pending") }

  # What is left of all of them, in one query.
  def self.balance_sum = sum(Arel.sql(BALANCE_SQL))

  def display_number = format("%04d", id)
  def audit_label = "#{self.class.model_name.human} #{display_number} · #{buyer&.name}"
  def human_payment_method = Invoice.human_attribute_name("payment_method/#{payment_method}")

  def pending? = status == "pending"
  def cancelled? = status == "cancelled"
  def human_status = self.class.human_attribute_name("status/#{status}")

  def applied_amount = applications.reject(&:new_record?).sum(0.to_d, &:amount)
  def refunded_amount = refunds.reject(&:new_record?).sum(0.to_d, &:amount)
  def balance = (amount - applied_amount - refunded_amount).round(2)
  # The % of it still free: 100 − what its applications took − what was
  # given back (as a % of the advance).
  def free_percent
    return 0.to_d unless amount.to_d.positive?

    [ (balance * 100 / amount).round(4), 0.to_d ].max
  end

  # Pending or cancelled, from what was applied and given back; cancelled
  # on the last of those days.
  def refresh_status!
    reload
    covered = balance <= 0
    last_day = [ applications.maximum(:applied_on), refunds.maximum(:refunded_on) ].compact.max
    update!(status: covered ? "cancelled" : "pending", cancelled_on: (last_day if covered))
  end

  # Nothing applied nor given back.
  def removable? = applications.none? && refunds.none?

  private
    def money_account_active
      errors.add(:money_account, :inactive) if money_account && !money_account.active?
    end

    def ensure_not_used
      return if removable?

      errors.add(:base, :used)
      throw :abort
    end
end
