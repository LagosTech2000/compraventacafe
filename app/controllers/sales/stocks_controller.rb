module Sales
  # Inventario: the coffee in stock by state and its kardex (what came in
  # with the purchases and left with the shipments), with the balance.
  class StocksController < ApplicationController
    def show
      authorize [ :sales, :stock ]
      @stock = CoffeeStock.new
      @filter = StockLedgerFilter.new(params)
      @entries, @next_page = @filter.results(nil)
      @ledger = @filter.ledger
    end
  end
end
