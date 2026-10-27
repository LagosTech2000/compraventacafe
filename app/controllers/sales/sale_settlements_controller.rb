module Sales
  # The buyer's settlement of a sale (Fernando, 2026-10-25): the total the
  # buyer pays per its own liquidation and why it differs. Once entered, it
  # is what is collected. Empty, the sale goes back to its own total.
  class SaleSettlementsController < ApplicationController
    before_action :set_sale

    def edit
      @sale.buyer_total ||= @sale.total
    end

    def update
      @sale.settle!(buyer_total: settlement_params[:buyer_total].presence, reason: settlement_params[:buyer_total_reason])
      close_modal_with notice: t(".success"), fallback: sales_sale_path(@sale)
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_content
    end

    private
      def set_sale
        @sale = Sale.includes(:buyer, :payments).find(params[:sale_id])
        authorize @sale, :settle?
      end

      def settlement_params
        params.expect(sale: [ :buyer_total, :buyer_total_reason ])
      end
  end
end
