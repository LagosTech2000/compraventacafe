module Loans
  class HomeController < ApplicationController
    def index
      authorize [ :loans, :home ]
      return unless module_home_or_first_tab("loans")

      loans = policy_scope(Loan)
      open_loans = loans.unpaid.includes(:payments, :supply_items, person: :photo_info)
      @balances = open_loans.to_h { |loan| [ loan, loan.balance ] }
      @overdue = open_loans.select(&:overdue?).sort_by(&:due_on)
      # Lent and collected of all time (Fernando, 2026-11-12): principal in
      # cash and in supplies (each loan's proportion), interest apart.
      principal, @lent_cash = loans.pick(Arel.sql("COALESCE(SUM(principal), 0)"), Arel.sql("COALESCE(SUM(cash_amount), 0)"))
      @lent_supplies = principal - @lent_cash
      payments = LoanPayment.where(loan_id: loans.select(:id))
      @interest_collected = payments.sum(:interest_amount)
      @cash_collected, @supplies_collected = collected_by_part(payments)
    end

    private
      # Each loan's principal collected, split as it was lent.
      def collected_by_part(payments)
        by_loan = payments.group(:loan_id).sum(:principal_amount)
        Loan.where(id: by_loan.keys).pluck(:id, :cash_amount, :principal).each_with_object([ 0.to_d, 0.to_d ]) do |(id, cash, principal), sums|
          cash_part, supplies_part = Loan.split_principal(by_loan[id], cash:, principal:)
          sums[0] += cash_part
          sums[1] += supplies_part
        end
      end
  end
end
