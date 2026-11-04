# A screen of the loans module that only reads its loans.
module Loans
  class SimulationPolicy < ApplicationPolicy
    self.module_key = "loans"
  end
end
