# A screen of the loans module that only reads its loans.
module Loans
  class DailyClosePolicy < ApplicationPolicy
    self.module_key = "loans"
  end
end
