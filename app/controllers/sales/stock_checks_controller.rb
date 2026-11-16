module Sales
  # Why the net pounds of a coffee state are not its gross × the usual
  # factor, and its sacks not gross ÷ 165 (StockCheck): administrators.
  class StockChecksController < ApplicationController
    def show
      authorize [ :sales, :stock_check ]
      @warehouse = Warehouse.find_by(id: params[:warehouse_id])
      @coffee_state = params.require(:coffee_state)
      @check = StockCheck.new(warehouse: @warehouse)
      @row = @check.row(@coffee_state)
      @parts = @check.explanation(@coffee_state)
      @purchases = @check.purchases_breakdown(@coffee_state)
      @shipments = @parts.find { it.key == :shipments }&.items || []
    end
  end
end
