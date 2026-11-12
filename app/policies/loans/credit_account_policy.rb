# A person's account (loans, history and score) inside the loans module.
module Loans
  class CreditAccountPolicy < ApplicationPolicy
    self.module_key = "loans"
    self.submodule_key = "credit_accounts"

    # The card beside «Nuevo préstamo» goes with the loans too.
    def card? = show? || user.present? && user.can?("loans.loans", :read)
  end
end
