module Sales
  # Inventario: the coffee in stock by state, of every warehouse or one, the
  # cherry waiting too long, and the kardex (every move with the balance).
  class StocksController < ApplicationController
    def show
      authorize [ :sales, :stock ]
      @filter = StockLedgerFilter.new(params)
      @warehouse = @filter.warehouse
      @stock = CoffeeStock.new(warehouse: @warehouse)
      @alert = CherryAlert.new(warehouse_id: @warehouse&.id)
      @entries, @next_page = @filter.results(nil)
      @ledger = @filter.ledger
      @warehouses = Warehouse.active.or(Warehouse.where(id: @warehouse&.id)).alphabetical
    end
  end
end
