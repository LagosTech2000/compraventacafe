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
      @conversion = authorize CoffeeConversion.new(from_state:, warehouse:, weighed_at: Time.current.change(sec: 0))
      @stock = CoffeeStock.new
    end

    def create
      @conversion = authorize CoffeeConversion.new(conversion_params.merge(created_by: Current.user))

      if @conversion.save
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
        @conversion = CoffeeConversion.includes(:warehouse, :output_warehouse, :created_by, :finished_by, :voided_by).find(params[:id])
        authorize @conversion unless action_name.in?(%w[void reopen])
      end

      def conversion_params
        params.expect(coffee_conversion: [ :from_state, :warehouse_id, :weighed_at, :input_gross_weight, :observations ])
      end
  end
end
