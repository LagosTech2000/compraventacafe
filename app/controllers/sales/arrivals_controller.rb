module Sales
  # The shipment weighed on the buyer's scale: its gross weight, sacks,
  # humidity and damage (or yield), the weight note and the day. The net
  # uses the purchase calculation; the difference with the local scale
  # shows at once.
  class ArrivalsController < ApplicationController
    before_action :set_shipment

    def edit
      @shipment.received_on ||= Time.zone.today
      @shipment.destination_sacks ||= @shipment.origin_sacks
      %w[humidity_percent damage_percent yield_factor].each do |input|
        @shipment["destination_#{input}"] ||= @shipment["origin_#{input}"]
      end
    end

    def update
      @shipment.assign_attributes(arrival_params)
      @shipment.receiving = true

      if @shipment.save
        close_modal_with notice: t(".success", number: @shipment.display_number), fallback: sales_shipment_path(@shipment)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_shipment
        @shipment = Shipment.includes(:buyer, :active_sale_line, :sale).find(params[:shipment_id])
        authorize @shipment, :receive?
      end

      def arrival_params
        params.expect(shipment: [ :received_on, :weight_note_number, :destination_gross_weight, :destination_sacks,
                                  :destination_humidity_percent, :destination_damage_percent, :destination_yield_factor, :lock_version ])
      end
  end
end
