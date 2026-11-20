# A loan the owners took from a bank or another person (Fernando,
# 2026-11-15: «préstamos que los dueños sacan, algo que ellos deben»):
# who owes it, to whom, how much, since when and, optionally, a monthly
# rate. Interest and payments work like the business's loans (LoanBalance):
# simple interest by day on the principal still owed, each payment pays the
# interest first. A development quoted apart (PaidFeature «owner_loans»).
#
# With an account, the money came into it and each payment goes out of
# its own (MoneyMovements «owner_loans», «owner_loan_payments»); without
# one, it moves no balance.
class OwnerLoan < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  include HasMoneyAccount
  include DayLock
  locks_day :disbursed_on, free: %w[paid_off_on]
  live_updates :finance

  MAX_AMOUNT = 100_000_000
  STATUSES = %w[active overdue paid].freeze

  belongs_to :created_by, class_name: "User"
  has_many :payments, -> { chronological }, class_name: "OwnerLoanPayment", dependent: :restrict_with_error, inverse_of: :owner_loan

  normalizes :owner_name, :lender_name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :owner_name, :lender_name, presence: true, length: { maximum: 120 }
  validates :disbursed_on, presence: true
  validates :principal, numericality: { greater_than: 0, less_than: MAX_AMOUNT }
  validates :monthly_interest_rate, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :observations, length: { maximum: 500 }
  validate { errors.add(:due_on, :before_disbursed) if due_on && disbursed_on && due_on < disbursed_on }

  scope :newest_first, -> { order(disbursed_on: :desc, id: :desc) }
  scope :unpaid, -> { where(paid_off_on: nil) }

  # What LoanBalance reads: interest from the day it was taken.
  def interest_starts_on = disbursed_on
  def balance(as_of: Time.zone.today) = LoanBalance.new(self, as_of:, payments: payments.to_a)

  def paid? = paid_off_on.present?
  def overdue?(today = Time.zone.today) = !paid? && due_on.present? && due_on < today
  def status = paid? ? "paid" : (overdue? ? "overdue" : "active")
  def human_status = self.class.human_attribute_name("status/#{status}")
  def display_number = format("%04d", id)
  def audit_label = "#{self.class.model_name.human} #{display_number} · #{lender_name}"
end
