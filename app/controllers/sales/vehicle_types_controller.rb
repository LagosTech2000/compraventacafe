module Sales
  # Vehicle types (Fernando, 2026-11-04): camión, pick-up… the user adds,
  # renames and deactivates them. From a vehicle's form (picker=1), a new
  # one is added there and chosen.
  class VehicleTypesController < ApplicationController
    before_action :set_vehicle_type, only: %i[ edit update ]

    def index
      authorize VehicleType
      @filter = VehicleTypeFilter.new(params)
      @vehicle_types, @next_page = @filter.results(policy_scope(VehicleType))
    end

    def new
      @vehicle_type = authorize VehicleType.new
    end

    def create
      @vehicle_type = authorize VehicleType.new(vehicle_type_params)

      if @vehicle_type.save
        close_modal_with notice: t(".success"), fallback: sales_vehicle_types_path,
                         event: "vehicle-type:created", detail: { id: @vehicle_type.id, label: @vehicle_type.name, name: @vehicle_type.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @vehicle_type.update(vehicle_type_params)
        close_modal_with notice: t(".success"), fallback: sales_vehicle_types_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_vehicle_type
        @vehicle_type = authorize VehicleType.find(params[:id])
      end

      def vehicle_type_params
        params.expect(vehicle_type: [ :name, :active ])
      end
  end
end
