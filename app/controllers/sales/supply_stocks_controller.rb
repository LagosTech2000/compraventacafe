module Sales
  # Inventario de insumos (Fernando, 2026-11-12): what there is of each
  # supply and the entries, filtered and in pages.
  class SupplyStocksController < ApplicationController
    def show
      authorize SupplyEntry, :index?
      @stock = SupplyStock.new
      @filter = SupplyEntryFilter.new(params)
      @entries, @next_page = @filter.results(policy_scope(SupplyEntry))
    end
  end
end
