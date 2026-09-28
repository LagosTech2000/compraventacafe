module Trading
  class DailyClosesController < ApplicationController
    include DateParam

    def show
      authorize [ :trading, :daily_close ]
      @daily_close = DailyClose.new(date_param)
    end
  end
end
