# Paying loans with a purchase registers loan payments (loans module) with
# the money of a purchase (trading module): it takes creating in the first
# and seeing the second, and a purchase whose money is still available.
class PurchaseLoanSettlementPolicy < ApplicationPolicy
  self.module_key = "loans"

  def create?
    super && user.can?("trading", :read) && record.purchase.accepts_loan_payments? && record.open_loans.any?
  end
end
