module Sales
  # Coffee converted to the next state (cherry → wet parchment → dry
  # parchment): the gross that goes in is weighed here and leaves its state
  # (in process); its result is entered after (ConversionResultsController).
  class CoffeeConversionsController < ApplicationController
    before_action :set_conversion, only: %i[ show void reopen ]

    def index
      authorize CoffeeConversion
      @filter = CoffeeConversionFilter.new(params)
      @conversions, @next_page = @filter.results(policy_scope(CoffeeConversion))
    end

    def show
    end

    def new
      from_state = params[:from_state].presence_in(CoffeeConversion::NEXT_STATE.keys) || "cherry"
      warehouse = Warehouse.active.find_by(id: params[:warehouse_id]) || Warehouse.main
      @conversion = authorize CoffeeConversion.new(from_state:, warehouse:, weighed_at: Time.current.change(sec: 0),
                                                   estimated_yield_percent: CoffeeConversion.default_yield_percent(from_state))
      @stock = CoffeeStock.new
    end

    def create
      @conversion = authorize CoffeeConversion.new(conversion_params.merge(created_by: Current.user))

      if save_with_lot
        close_modal_with notice: t(".success", number: @conversion.display_number), fallback: sales_coffee_conversion_path(@conversion)
      else
        @stock = CoffeeStock.new
        render :new, status: :unprocessable_content
      end
    end

    def void
      authorize @conversion, :void?
      @conversion.void!(Current.user)
      redirect_back_or_to sales_coffee_conversion_path(@conversion), notice: t(".success")
    end

    def reopen
      authorize @conversion, :reopen?
      @conversion.reopen!
      redirect_back_or_to sales_coffee_conversion_path(@conversion), notice: t(".success")
    end

    private
      def set_conversion
        @conversion = CoffeeConversion.includes(:warehouse, :output_warehouse, :processing_site, :created_by, :finished_by, :voided_by).find(params[:id])
        authorize @conversion unless action_name.in?(%w[void reopen])
      end

      # The invoices marked in «¿Qué café lleva?» (Fernando, 2026-11-22)
      # make a lot of their own, saved with the process or not at all
      # (ShipmentLot, as in a shipment).
      def save_with_lot
        @invoice_ids = Array(params.dig(:coffee_conversion, :invoice_ids)).compact_blank
        return @conversion.save if @invoice_ids.empty? || !lots_from_invoices?

        chosen_lots = @conversion.batch_ids
        @conversion.warehouse ||= Warehouse.main!
        saved = CoffeeConversion.transaction do
          lot = ShipmentLot.new(shipment: @conversion, invoice_ids: @invoice_ids, invoices: policy_scope(Invoice), user: Current.user,
                                percents: params.dig(:coffee_conversion, :invoice_percents)&.permit(*@invoice_ids)&.to_h || {}).call
          unless lot
            lot_errors = @conversion.errors.full_messages
            @conversion.valid?
            lot_errors.each { @conversion.errors.add(:base, it) }
            raise ActiveRecord::Rollback
          end
          @conversion.batch_ids = chosen_lots + [ lot.id ]
          @conversion.save || raise(ActiveRecord::Rollback)
        end
        @conversion.batch_ids = chosen_lots unless saved
        saved
      end

      def lots_from_invoices? = policy(CoffeeBatch).create? && policy(CoffeeBatchInvoice.new).create?
      helper_method :lots_from_invoices?

      def conversion_params
        params.expect(coffee_conversion: [ :from_state, :warehouse_id, :processing_site_id, :weighed_at, :input_gross_weight, :estimated_yield_percent,
                                                         :input_humidity_percent, :observations, { batch_ids: [] } ])
      end
  end
end
