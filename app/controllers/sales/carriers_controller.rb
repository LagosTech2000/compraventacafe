module Sales
  # Carriers: who hauls the coffee to the buyer, and the shipments they took.
  class CarriersController < ApplicationController
    before_action :set_carrier, only: %i[ show edit update ]

    def index
      authorize Carrier
      @filter = CarrierFilter.new(params)
      @carriers, @next_page = @filter.results(policy_scope(Carrier))
    end

    def show
      @filter = BuyerShipmentFilter.new(params)
      @shipments, @next_page = @filter.results(@carrier.shipments)
    end

    def new
      @carrier = authorize Carrier.new
    end

    def create
      @carrier = authorize Carrier.new(carrier_params)

      if @carrier.save
        close_modal_with notice: t(".success"), fallback: sales_carrier_path(@carrier),
                         event: "carrier:created", detail: { id: @carrier.id, label: @carrier.name, name: @carrier.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @carrier.update(carrier_params)
        close_modal_with notice: t(".success"), fallback: sales_carrier_path(@carrier)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_carrier
        @carrier = authorize Carrier.find(params[:id])
      end

      def carrier_params
        params.expect(carrier: [ :name, :rtn, :phone, :contact_name, :observations, :active ])
      end
  end
end
