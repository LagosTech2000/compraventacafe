module Finance
  # The single ledger: every movement of money of every module.
  class MovementsController < ApplicationController
    def index
      authorize [ :finance, :movement ]
      @filter = MovementFilter.new(params)
      @filter.user = Current.user
      @rows, @next_page = @filter.results(nil)
    end
  end
end
