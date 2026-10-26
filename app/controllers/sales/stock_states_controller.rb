module Sales
  # One coffee state of the stock (client, 2026-10-26: «al hacer clic en
  # cualquiera de los inventarios»), or all of them: its figures, its value
  # and its lots with what is left of each, of every warehouse or one.
  class StockStatesController < ApplicationController
    def show
      authorize [ :sales, :stock ]
      @warehouse = Warehouse.find_by(id: params[:warehouse_id])
      @coffee_state = params[:coffee_state].presence_in(Purchase::COFFEE_STATES)
      engine = CoffeeLots.new
      @lots = CoffeeLots.preload(engine.lots(coffee_state: @coffee_state, warehouse_id: @warehouse&.id))
      @totals = engine.totals(@lots)
      @first_out = @lots.group_by { [ it.coffee_state, it.warehouse_id ] }.values.map(&:first)
      stock = CoffeeStock.new(warehouse: @warehouse)
      @rows = @coffee_state ? [ stock.row(@coffee_state) ] : stock.rows
      @alert = CherryAlert.new(lots: engine, warehouse_id: @warehouse&.id) if @coffee_state.in?([ nil, "cherry" ])
      @warehouses = Warehouse.where(id: @lots.map(&:warehouse_id).uniq).or(Warehouse.active).alphabetical
    end
  end
end
