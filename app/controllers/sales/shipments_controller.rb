module Sales
  # Vehicles that leave with coffee for a buyer ("salidas de camión"), weighed
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
      # From a person's panel (the fingerprint reader): with them as its driver.
      driver = StaffMember.active.find_by(id: params[:driver_id])
      @shipment = authorize Shipment.new(departed_at: Time.current.change(sec: 0), coffee_state: state, buyer:, driver:,
                                         **PurchaseDefaults.inputs_for(state).transform_keys { :"origin_#{it}" })
      @stock = CoffeeStock.new
    end

    def create
      @shipment = authorize Shipment.new(shipment_params.merge(created_by: Current.user, origin_skippable: Current.user.admin?, asking_reasons: true))

      if save_with_lot
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
      @shipment.origin_skippable = Current.user.admin?
      @shipment.asking_reasons = true
      @shipment.assign_attributes(shipment_params)
      if save_with_lot
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
        @shipment = Shipment.includes(:buyer, :warehouse, :carrier, :vehicle, { driver: :person }, :created_by, :voided_by, :active_sale_line, :sale, :weighings).find(params[:id])
        authorize @shipment unless action_name == "void"
      end

      # «¿Qué café lleva?» (Fernando, 2026-11-18): the invoices chosen make
      # a lot of their own, saved with the shipment or not at all.
      def save_with_lot
        @invoice_ids = Array(params.dig(:shipment, :invoice_ids)).compact_blank
        return @shipment.save if @invoice_ids.empty? || !lots_from_invoices?

        chosen_lots = @shipment.batch_ids
        saved = Shipment.transaction do
          lot = ShipmentLot.new(shipment: @shipment, invoice_ids: @invoice_ids, invoices: policy_scope(Invoice), user: Current.user,
                                percents: params.dig(:shipment, :invoice_percents)&.permit(*@invoice_ids)&.to_h || {}).call
          unless lot
            lot_errors = @shipment.errors.full_messages
            @shipment.valid?
            lot_errors.each { @shipment.errors.add(:base, it) }
            raise ActiveRecord::Rollback
          end
          @shipment.batch_ids = chosen_lots + [ lot.id ]
          @shipment.save || raise(ActiveRecord::Rollback)
        end
        @shipment.batch_ids = chosen_lots unless saved
        saved
      end

      def lots_from_invoices? = policy(CoffeeBatch).create? && policy(CoffeeBatchInvoice.new).create?
      helper_method :lots_from_invoices?

      def shipment_params
        params.expect(shipment: [ :skip_origin, :departed_at, :buyer_id, :warehouse_id, :coffee_state, :transport_mode, :carrier_id, :trip_price, :vehicle_id, :driver_id, :driver_name, :observations, :shrink_reason, { batch_ids: [] },
                                  :origin_gross_weight, :origin_sacks, :origin_humidity_percent, :origin_damage_percent,
                                  :origin_yield_factor, :origin_weight_mode, :lock_version,
                                  weighings_attributes: [ [ :id, :gross_weight, :sacks, :_destroy ] ] ])
      end

      def shipment_totals(scope)
        scope = scope.unscope(:order, :includes)
        { count: scope.count, sacks: scope.sum(:origin_sacks), origin_net: scope.sum(:origin_net_weight), origin_gross: scope.sum(:origin_gross_weight),
          destination_net: scope.where.not(destination_net_weight: nil).sum(:destination_net_weight),
          destination_gross: scope.where.not(destination_net_weight: nil).sum(:destination_gross_weight),
          compared_origin: scope.where.not(destination_net_weight: nil).sum(:origin_net_weight),
          # Only the ones with both scales (Fernando, 2026-11-12).
          compared_destination: scope.where.not(destination_net_weight: nil).where.not(origin_net_weight: nil).sum(:destination_net_weight) }
      end
  end
end
