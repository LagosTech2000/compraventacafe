module Sales
  # Closing a lot without a shipment or a process, and reopening it
  # (Fernando, 2026-11-22; administrators, CoffeeBatchClosing).
  class CoffeeBatchClosingsController < ApplicationController
    before_action :set_batch

    def new
      authorize @batch, :close?
    end

    def create
      authorize @batch, :close?
      closing = CoffeeBatchClosing.new(batch: @batch, user: Current.user)
      if closing.close(reason: params[:close_reason], gone: params[:gone] == "1")
        close_modal_with notice: t(".success", batch: @batch.label), fallback: sales_coffee_batch_path(@batch)
      else
        @errors = closing.errors
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      authorize @batch, :reopen?
      closing = CoffeeBatchClosing.new(batch: @batch, user: Current.user)
      if closing.reopen
        redirect_to sales_coffee_batch_path(@batch), notice: t(".success", batch: @batch.label)
      else
        redirect_to sales_coffee_batch_path(@batch), alert: closing.errors.to_sentence
      end
    end

    private
      def set_batch
        @batch = CoffeeBatch.find(params[:coffee_batch_id])
      end
  end
end
