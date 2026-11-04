module Sales
  # Vehicles (camión, pick-up…): the ones that carry the coffee to the buyer, and their shipments.
  class VehiclesController < ApplicationController
    before_action :set_vehicle, only: %i[ show edit update ]

    def index
      authorize Vehicle
      @filter = VehicleFilter.new(params)
      @vehicles, @next_page = @filter.results(policy_scope(Vehicle))
    end

    def show
      @filter = BuyerShipmentFilter.new(params)
      @shipments, @next_page = @filter.results(@vehicle.shipments)
    end

    def new
      @vehicle = authorize Vehicle.new
    end

    def create
      @vehicle = authorize Vehicle.new(vehicle_params)

      if @vehicle.save
        close_modal_with notice: t(".success"), fallback: sales_vehicle_path(@vehicle),
                         event: "vehicle:created", detail: { id: @vehicle.id, label: @vehicle.label, name: @vehicle.label }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @vehicle.update(vehicle_params)
        close_modal_with notice: t(".success"), fallback: sales_vehicle_path(@vehicle)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_vehicle
        @vehicle = authorize Vehicle.find(params[:id])
      end

      def vehicle_params
        params.expect(vehicle: [ :vehicle_type_id, :plate, :brand_model, :color, :capacity_quintals, :own, :observations, :active ])
      end
  end
end
