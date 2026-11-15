module Sales
  # Lots a shipment takes after it was registered (Fernando, 2026-11-13):
  # the free lots of its coffee state and warehouse, marked and taken at
  # once; each one let go apart.
  class ShipmentBatchesController < ApplicationController
    before_action :set_shipment

    def new
      authorize @shipment, :create?, policy_class: ShipmentBatchPolicy
      @filter = CoffeeBatchFilter.new(params.permit(:q, :from, :to, :sort, :dir, :page))
      @batches, @next_page = @filter.results(eligible)
      @totals = CoffeeBatch::Totals.by_batch(@batches.map(&:id))
    end

    def create
      authorize @shipment, :create?, policy_class: ShipmentBatchPolicy
      ids = eligible.where(id: Array(params[:batch_ids])).pluck(:id)
      return redirect_to(new_sales_shipment_batch_path(@shipment), alert: t(".none")) if ids.empty?

      @shipment.update!(batch_ids: @shipment.coffee_batch_ids + ids)
      redirect_to sales_shipment_path(@shipment, anchor: "shipment-cost"), notice: t(".success", count: ids.size)
    end

    def destroy
      authorize @shipment, :destroy?, policy_class: ShipmentBatchPolicy
      batch = @shipment.coffee_batches.find(params[:id])
      batch.update!(shipment: nil)
      redirect_to sales_shipment_path(@shipment, anchor: "shipment-cost"), notice: t(".success", batch: batch.label), status: :see_other
    end

    private
      def set_shipment
        @shipment = Shipment.find(params[:shipment_id])
      end

      def eligible
        policy_scope(CoffeeBatch).free.where(coffee_state: @shipment.coffee_state, warehouse_id: @shipment.warehouse_id)
      end
  end
end
