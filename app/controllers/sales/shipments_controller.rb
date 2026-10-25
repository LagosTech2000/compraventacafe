module Sales
  # Trucks that leave with coffee for a buyer ("salidas de camión"), weighed
  # on the local scale; weighed again at the buyer's (ArrivalsController).
  class ShipmentsController < ApplicationController
    before_action :set_shipment, only: %i[ show edit update void ]

    def index
      authorize Shipment
      @filter = ShipmentFilter.new(params)
      @shipments, @next_page = @filter.results(policy_scope(Shipment))
      @totals = shipment_totals(@filter.apply(policy_scope(Shipment)))
    end

    def show
    end

    def new
      buyer = Buyer.active.find_by(id: params[:buyer_id])
      state = PurchaseDefaults::COFFEE_STATE
      @shipment = authorize Shipment.new(departed_at: Time.current.change(sec: 0), coffee_state: state, buyer:,
                                         **PurchaseDefaults.inputs_for(state).transform_keys { :"origin_#{it}" })
      @stock = CoffeeStock.new
    end

    def create
      @shipment = authorize Shipment.new(shipment_params.merge(created_by: Current.user))

      if @shipment.save
        close_modal_with notice: t(".success", number: @shipment.display_number, buyer: @shipment.buyer.name),
                         fallback: sales_shipment_path(@shipment)
      else
        @stock = CoffeeStock.new
        render :new, status: :unprocessable_content
      end
    end

    def edit
      @stock = CoffeeStock.new
    end

    def update
      if @shipment.update(shipment_params)
        close_modal_with notice: t(".success"), fallback: sales_shipment_path(@shipment)
      else
        @stock = CoffeeStock.new
        render :edit, status: :unprocessable_content
      end
    end

    def void
      authorize @shipment, :void?
      @shipment.void!(Current.user)

      if modal_request?
        close_modal_with notice: t(".success"), fallback: sales_shipments_path
      else
        redirect_back_or_to sales_shipments_path, notice: t(".success")
      end
    end

    private
      def set_shipment
        @shipment = Shipment.includes(:buyer, :created_by, :voided_by, :active_sale_line, :sale, :weighings).find(params[:id])
        authorize @shipment unless action_name == "void"
      end

      def shipment_params
        params.expect(shipment: [ :departed_at, :buyer_id, :coffee_state, :remission_number, :carrier_name, :vehicle_plate, :observations,
                                  :origin_gross_weight, :origin_sacks, :origin_humidity_percent, :origin_damage_percent,
                                  :origin_yield_factor, :origin_weight_mode, :lock_version,
                                  weighings_attributes: [ [ :id, :gross_weight, :sacks, :_destroy ] ] ])
      end

      def shipment_totals(scope)
        scope = scope.unscope(:order, :includes)
        { count: scope.count, sacks: scope.sum(:origin_sacks), origin_net: scope.sum(:origin_net_weight),
          destination_net: scope.where.not(destination_net_weight: nil).sum(:destination_net_weight),
          compared_origin: scope.where.not(destination_net_weight: nil).sum(:origin_net_weight) }
      end
  end
end
