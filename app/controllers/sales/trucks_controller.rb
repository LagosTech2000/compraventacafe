module Sales
  # Trucks: the ones that carry the coffee to the buyer, and their shipments.
  class TrucksController < ApplicationController
    before_action :set_truck, only: %i[ show edit update ]

    def index
      authorize Truck
      @filter = TruckFilter.new(params)
      @trucks, @next_page = @filter.results(policy_scope(Truck))
    end

    def show
      @filter = BuyerShipmentFilter.new(params)
      @shipments, @next_page = @filter.results(@truck.shipments)
    end

    def new
      @truck = authorize Truck.new
    end

    def create
      @truck = authorize Truck.new(truck_params)

      if @truck.save
        close_modal_with notice: t(".success"), fallback: sales_truck_path(@truck),
                         event: "truck:created", detail: { id: @truck.id, label: @truck.label, name: @truck.label }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @truck.update(truck_params)
        close_modal_with notice: t(".success"), fallback: sales_truck_path(@truck)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_truck
        @truck = authorize Truck.find(params[:id])
      end

      def truck_params
        params.expect(truck: [ :plate, :brand_model, :color, :capacity_quintals, :own, :observations, :active ])
      end
  end
end
