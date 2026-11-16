# The owners' loans: by text (owner or lender), status and dates, with the
# totals of all of them (OwnerLoanFilter#totals).
class OwnerLoanFilter < ListFilter
  field :q, :text
  field :status, :choice, in: OwnerLoan::STATUSES
  field :from, :date
  field :to, :date

  sorts disbursed_on: "owner_loans.disbursed_on", owner: text("owner_loans.owner_name"), lender: text("owner_loans.lender_name"),
        principal: "owner_loans.principal", rate: "owner_loans.monthly_interest_rate", due_on: "owner_loans.due_on",
        owed: { ruby: ->(loan) { loan.balance.total_owed } }

  def apply(scope)
    scope = scope.where("owner_loans.owner_name ILIKE :q OR owner_loans.lender_name ILIKE :q", q: like(q)) if q
    scope = scope.where(disbursed_on: from..) if from
    scope = scope.where(disbursed_on: ..to) if to
    scope = case status
    when "paid" then scope.where.not(paid_off_on: nil)
    when "overdue" then scope.unpaid.where(due_on: ...Time.zone.today)
    when "active" then scope.unpaid.where("owner_loans.due_on IS NULL OR owner_loans.due_on >= ?", Time.zone.today)
    else scope
    end
    scope.includes(:payments, :money_account).newest_first
  end

  # What all the loans filtered add up to.
  Totals = Data.define(:count, :principal, :principal_paid, :interest_paid, :owed)

  def totals(scope)
    loans = apply(scope).to_a
    balances = loans.map(&:balance)
    Totals.new(count: loans.size, principal: loans.sum(0.to_d) { it.principal.to_d }, principal_paid: balances.sum(0.to_d, &:principal_paid),
               interest_paid: balances.sum(0.to_d, &:interest_paid), owed: balances.sum(0.to_d, &:total_owed))
  end
end
