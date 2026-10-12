module Trading
  class HomeController < ApplicationController
    def index
      authorize [ :trading, :home ]
      @daily_close = DailyClose.new(Time.zone.today)
      @uninvoiced = PurchaseSummary.new(policy_scope(Purchase).uninvoiced)
      @pending_invoices = policy_scope(Invoice).unpaid.includes(:payments, purchases: :loan_payments)
      # What is left to pay the producers on them.
      @pending_total = @pending_invoices.sum(&:balance_due)
      @season = Season.current
      @season_summary = PurchaseSummary.new(policy_scope(Purchase).active.in_season(@season))
    end
  end
end
