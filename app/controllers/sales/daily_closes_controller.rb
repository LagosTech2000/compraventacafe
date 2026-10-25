module Sales
  class DailyClosesController < ApplicationController
    include DateParam

    def show
      authorize [ :sales, :daily_close ]
      @daily_close = SalesDailyClose.new(date_param)
    end
  end
end
