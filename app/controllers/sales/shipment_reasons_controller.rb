module Sales
  # Why a shipment's differences pass their tolerance (Fernando,
  # 2026-11-18): the shrink (purchases of its lots ↔ local scale) and the
  # buyer's scale ↔ local. Asked when they are entered; here, for the ones
  # that passed later (lots added after) or to correct what was written.
  class ShipmentReasonsController < ApplicationController
    before_action :set_shipment

    def edit
    end

    def update
      if @shipment.update(params.expect(shipment: %i[ shrink_reason difference_reason ]))
        close_modal_with notice: t(".success", number: @shipment.display_number), fallback: sales_shipment_path(@shipment)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_shipment
        @shipment = Shipment.find(params[:shipment_id])
        authorize @shipment, :explain?
      end
  end
end
