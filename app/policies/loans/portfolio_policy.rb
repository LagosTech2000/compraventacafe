# A screen of the loans module that only reads its loans.
module Loans
  class PortfolioPolicy < ApplicationPolicy
    self.module_key = "loans"
    self.submodule_key = "portfolio"
  end
end
