# "Simulador de préstamo" (Fernando, 2026-11-03): what a loan would owe on a
# date, with the same rule as every loan (LoanBalance). Nothing is saved.
class LoanSimulation
  include ActiveModel::Model
  include ActiveModel::Attributes

  # How far the month-by-month table goes.
  MONTHS = 6

  attribute :amount, :decimal
  attribute :monthly_interest_rate, :decimal
  attribute :disbursed_on, :date
  attribute :paid_on, :date
  attribute :interest_grace, :boolean, default: false

  validates :amount, numericality: { greater_than: 0, less_than: Loan::MAX_AMOUNT }
  validates :monthly_interest_rate, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :disbursed_on, :paid_on, presence: true
  validate :paid_on_not_before_disbursement

  Point = Data.define(:date, :days, :interest, :total)

  def self.model_name = ActiveModel::Name.new(self, nil, "LoanSimulation")

  def days = (paid_on - disbursed_on).to_i
  def at(date) = point(date)
  def result = point(paid_on)

  # Interest one day adds while nothing is paid (after the grace days).
  def interest_per_day = (amount * monthly_interest_rate / 100 / LoanBalance::DAYS_PER_MONTH).round(2)

  # The loan's date plus each 30 days, up to MONTHS.
  def by_month = (1..MONTHS).map { point(disbursed_on + (it * LoanBalance::DAYS_PER_MONTH)) }

  private
    def loan
      @loan ||= Loan.new(principal: amount, monthly_interest_rate:, disbursed_on:, interest_grace:)
    end

    def point(date)
      balance = LoanBalance.new(loan, as_of: date, payments: [])
      Point.new(date:, days: (date - disbursed_on).to_i, interest: balance.interest_owed, total: balance.total_owed)
    end

    def paid_on_not_before_disbursement
      errors.add(:paid_on, :before_disbursement) if paid_on && disbursed_on && paid_on < disbursed_on
    end
end
