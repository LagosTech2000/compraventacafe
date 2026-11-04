module Loans
  # "Cierre diario de préstamos": what was lent and collected on a day.
  class DailyClosesController < ApplicationController
    include DateParam

    def show
      authorize [ :loans, :daily_close ]
      @daily_close = LoanDailyClose.new(date_param)
    end
  end
end
