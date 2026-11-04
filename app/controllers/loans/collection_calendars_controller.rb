module Loans
  # "Calendario de cobro": what is due week by week.
  class CollectionCalendarsController < ApplicationController
    def show
      authorize [ :loans, :collection_calendar ]
      @calendar = LoanCalendar.new
      @bucket = @calendar.selected(params[:week].to_s)
    end
  end
end
