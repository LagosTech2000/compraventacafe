# A cash count ("arqueo", Fernando, 2026-10-25): the money really counted in
# an account (the cash box, usually) against what the system says it had at
# the end of that day (AccountBalance), kept as it was then. The difference
# shows the same day that something was not registered. Registered or
# removed, never edited.
class CashCount < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  belongs_to :money_account
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :counted_on, presence: true
  validates :counted_amount, numericality: { greater_than_or_equal_to: 0, less_than: Expense::MAX_AMOUNT }
  validates :observations, length: { maximum: 500 }
  validate { errors.add(:counted_on, :future) if counted_on&.future? }
  validate { errors.add(:money_account, :inactive) if money_account && !money_account.active? }

  before_validation :take_system_balance, on: :create

  scope :newest_first, -> { order(counted_on: :desc, id: :desc) }

  # Counted − the system's balance: below zero, money is missing.
  def difference = counted_amount - system_balance

  def audit_label = "#{money_account&.name} · #{I18n.l(counted_on) if counted_on}"

  private
    def take_system_balance
      self.system_balance = AccountBalance.new(as_of: counted_on).for(money_account) if money_account && counted_on
    end
end
