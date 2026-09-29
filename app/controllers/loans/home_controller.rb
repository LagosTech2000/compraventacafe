module Loans
  class HomeController < ApplicationController
    def index
      authorize [ :loans, :home ]
      open_loans = policy_scope(Loan).unpaid.includes(:person, :payments)
      @balances = open_loans.to_h { |loan| [ loan, loan.balance ] }
      @overdue = open_loans.select(&:overdue?).sort_by(&:due_on)
    end
  end
end
