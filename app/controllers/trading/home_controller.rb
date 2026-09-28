module Trading
  class HomeController < ApplicationController
    def index
      authorize [ :trading, :home ]
      @daily_close = DailyClose.new(Time.zone.today)
      @uninvoiced = PurchaseSummary.new(policy_scope(Purchase).uninvoiced)
      @pending_invoices = policy_scope(Invoice).pending
      @pending_total = PurchaseSummary.new(Purchase.where(invoice_id: @pending_invoices.select(:id))).total
    end
  end
end
