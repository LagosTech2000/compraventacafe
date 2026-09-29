# What a loan owes on a date, with simple interest as the owner defined it
# (2026-09-28):
#
#   interest runs daily on the principal still owed:
#     interest = principal owed × monthly rate × days / 30
#   a payment covers the interest owed first; the rest lowers the principal
#
# Interest keeps running after the due date at the same rate: there is no
# late fee (not defined). Each payment stores how it was split, so past
# payments do not change if the rule changes; only the days since the last
# payment are computed here.
class LoanBalance
  DAYS_PER_MONTH = 30

  attr_reader :as_of, :principal_owed, :interest_owed, :principal_paid, :interest_paid

  def initialize(loan, as_of: Time.zone.today, payments: loan.payments.chronological)
    @rate = loan.monthly_interest_rate.to_d / 100
    @principal_owed = loan.principal.to_d
    @principal_paid = @interest_paid = unpaid_interest = 0.to_d
    last_date = loan.disbursed_on

    payments.each do |payment|
      unpaid_interest += interest_between(last_date, payment.paid_on)
      unpaid_interest -= payment.interest_amount
      @principal_owed -= payment.principal_amount
      @interest_paid += payment.interest_amount
      @principal_paid += payment.principal_amount
      last_date = payment.paid_on
    end

    @as_of = [ as_of, last_date ].max
    @interest_owed = unpaid_interest + interest_between(last_date, @as_of)
  end

  def total_owed
    principal_owed + interest_owed
  end

  def settled?
    total_owed.zero?
  end

  # How a payment of `amount` on #as_of splits: [interest, principal].
  def split(amount)
    interest = [ amount.to_d, interest_owed ].min
    [ interest, amount.to_d - interest ]
  end

  private
    def interest_between(from, to)
      days = (to - from).to_i
      return 0.to_d unless days.positive?

      (principal_owed * @rate * days / DAYS_PER_MONTH).round(2)
    end
end
