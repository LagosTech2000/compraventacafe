module Sales
  # «Cuadre del día» (Fernando, 2026-11-18): the day's coffee by state and
  # by shipment, against the physical counts (StockReconciliation).
  class StockReconciliationsController < ApplicationController
    def show
      authorize [ :sales, :stock_reconciliation ]
      @date = (Date.iso8601(params[:date].to_s) rescue nil) || Time.zone.today
      @date = Time.zone.today if @date > Time.zone.today
      @warehouses = Warehouse.alphabetical
      @warehouse = @warehouses.find { it.id == params[:warehouse_id].to_i }
      @reconciliation = StockReconciliation.new(date: @date, warehouse: @warehouse)
    end
  end
end
