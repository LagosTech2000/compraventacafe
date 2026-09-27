module Trading
  class HomeController < ApplicationController
    def index
      authorize [ :trading, :home ]
      @daily_close = DailyClose.new(Time.zone.today)
      @pending_invoices_count = policy_scope(Invoice).pending.count
    end
  end
end
