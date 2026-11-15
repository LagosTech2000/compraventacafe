module Sales
  # Lots of purchased coffee (Fernando, 2026-11-13): made with a limit of
  # gross pounds in a warehouse, then filled with shares of purchase
  # invoices (CoffeeBatchInvoicesController), and taken by a shipment. From
  # «Nueva salida» (picker=1) the lot is made in the modal and comes back to
  # the shipment chosen.
  class CoffeeBatchesController < ApplicationController
    before_action :set_batch, only: %i[ show edit update destroy ]

    def index
      authorize CoffeeBatch
      @filter = CoffeeBatchFilter.new(params)
      @batches, @next_page = @filter.results(policy_scope(CoffeeBatch))
      @totals = CoffeeBatch::Totals.by_batch(@batches.map(&:id))
    end

    def show
      @batch_invoices = @batch.batch_invoices.includes(invoice: [ :purchases, { producer: :person } ]).to_a
    end

    def new
      @batch = authorize CoffeeBatch.new(batched_on: Time.zone.today, coffee_state: params[:coffee_state].presence_in(Purchase::COFFEE_STATES),
                                         warehouse_id: params[:warehouse_id].presence || Warehouse.main&.id)
    end

    def create
      @batch = authorize CoffeeBatch.new(batch_params.merge(created_by: Current.user))
      if @batch.save
        # Next: its invoices, in the same window.
        redirect_to new_sales_coffee_batch_invoice_path(@batch, picker: params[:picker].presence), notice: t(".success", batch: @batch.label)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @batch.update(batch_params)
        close_modal_with notice: t(".success"), fallback: sales_coffee_batch_path(@batch)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @batch.destroy
        redirect_to sales_coffee_batches_path, notice: t(".success", batch: @batch.label), status: :see_other
      else
        redirect_to sales_coffee_batch_path(@batch), alert: @batch.errors.full_messages.to_sentence
      end
    end

    private
      def set_batch
        @batch = authorize CoffeeBatch.includes(:warehouse, :created_by, :shipment).find(params[:id])
      end

      def batch_params
        params.expect(coffee_batch: [ :batched_on, :coffee_state, :warehouse_id, :gross_limit, :observations ])
      end
  end
end
