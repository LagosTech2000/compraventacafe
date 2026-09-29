# A person's account (loans, history and score) inside the loans module.
module Loans
  class CreditAccountPolicy < ApplicationPolicy
    self.module_key = "loans"
  end
end
