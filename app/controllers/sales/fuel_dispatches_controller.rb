module Sales
  # «Combustible» (Fernando, 2026-11-22): the business's fuel and oil
  # dispatched to its vehicles, by day and by vehicle, and what is left.
  class FuelDispatchesController < ApplicationController
    def show
      authorize [ :sales, :fuel_dispatch ]
      @filter = FuelDispatchFilter.new(params)
    end
  end
end
