module Loans
  class HomeController < ApplicationController
    def index
      authorize [ :loans, :home ]
      return unless module_home_or_first_tab("loans")

      loans = policy_scope(Loan)
      open_loans = loans.unpaid.includes(:payments, :supply_items, person: :photo_info)
      @balances = open_loans.to_h { |loan| [ loan, loan.balance ] }
      @overdue = open_loans.select(&:overdue?).sort_by(&:due_on)
      # Pendientes, in a vertical card on the left (Fernando, 2026-11-22):
      # overdue, due soon, supplies to deliver and who can pay with coffee.
      today = Time.zone.today
      @due_soon = open_loans.reject(&:overdue?).select { it.due_on.between?(today, today + Dashboard::DUE_SOON_DAYS) }.sort_by { [ it.due_on, it.id ] }
      @to_deliver = SupplyStock.counted_lines.to_deliver.where(loan_id: loans.select(:id))
                               .includes(:supply, loan: { person: :photo_info }).order("loans.disbursed_on", :id).to_a
      @coffee_rows = (CoffeeCollectionFilter.rows.sort_by { -it.available } if policy([ :loans, :coffee_collection ]).show?)
      # Lent and collected of all time (Fernando, 2026-11-12): principal in
      # cash and in supplies (each loan's proportion), interest apart.
      principal, @lent_cash = loans.pick(Arel.sql("COALESCE(SUM(principal), 0)"), Arel.sql("COALESCE(SUM(cash_amount), 0)"))
      @lent_supplies = principal - @lent_cash
      payments = LoanPayment.where(loan_id: loans.select(:id))
      @interest_collected = payments.sum(:interest_amount)
      @cash_collected, @supplies_collected = collected_by_part(payments)
      # The money of the loans (Fernando, 2026-11-23: no loans' account; its
      # numbers here): the cash lent from an account, what came in money and
      # what was paid with coffee or by payroll (no money moved).
      by_method = payments.group(:payment_method).sum(:amount)
      @money = { cash_out: loans.where.not(money_account_id: nil).sum(:cash_amount),
                 money_in: LoanPayment::PAYMENT_METHODS.sum { by_method.fetch(it, 0) },
                 coffee_in: by_method.fetch(LoanPayment::COFFEE, 0), payroll_in: by_method.fetch(LoanPayment::PAYROLL, 0) }
      @money[:net] = @money[:money_in] - @money[:cash_out]
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
