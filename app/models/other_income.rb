# Money that comes into an account from outside the modules (Fernando,
# 2026-10-23): the owner's contributions, a bank loan, a sale of something
# that is not coffee… So an account's balance is complete.
class OtherIncome < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  belongs_to :money_account
  belongs_to :created_by, class_name: "User"

  normalizes :concept, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :received_on, presence: true
  validates :concept, presence: true, length: { maximum: 200 }
  validates :amount, numericality: { greater_than: 0, less_than: Expense::MAX_AMOUNT }
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validates :observations, length: { maximum: 500 }
  validate { errors.add(:money_account, :inactive) if will_save_change_to_money_account_id? && money_account && !money_account.active? }

  scope :newest_first, -> { order(received_on: :desc, id: :desc) }

  def audit_label = concept
  def human_payment_method = Invoice.human_attribute_name("payment_method/#{payment_method}")
end
