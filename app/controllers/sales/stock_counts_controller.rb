module Sales
  # Physical counts of a warehouse (Fernando, 2026-11-18), each with the
  # adjustment that leaves the stock as counted (StockCount).
  class StockCountsController < ApplicationController
    before_action :set_count, only: %i[ show void ]

    def index
      authorize StockCount
      @filter = StockCountFilter.new(params)
      @counts, @next_page = @filter.results(policy_scope(StockCount))
    end

    def show
      @portions = @count.voided? ? [] : CoffeeLots.new.portions_for(@count)
    end

    def new
      warehouse = Warehouse.active.find_by(id: params[:warehouse_id]) || Warehouse.main
      state = params[:coffee_state].presence_in(Purchase::COFFEE_STATES) || PurchaseDefaults::COFFEE_STATE
      @count = authorize StockCount.new(counted_at: Time.current.change(sec: 0), warehouse:, coffee_state: state)
    end

    def create
      @count = authorize StockCount.new(count_params.merge(created_by: Current.user))

      if @count.save
        close_modal_with notice: t(".success", number: @count.display_number), fallback: sales_stock_count_path(@count)
      else
        render :new, status: :unprocessable_content
      end
    end

    def void
      authorize @count, :void?
      @count.void!(Current.user, reason: params.dig(:stock_count, :void_reason))
      redirect_to sales_stock_count_path(@count), notice: t(".success")
    rescue ActiveRecord::RecordInvalid
      redirect_to sales_stock_count_path(@count), alert: @count.errors.full_messages.to_sentence
    end

    private
      def set_count
        @count = StockCount.includes(:warehouse, :created_by, :voided_by).find(params[:id])
        authorize @count unless action_name == "void"
      end

      def count_params
        params.expect(stock_count: [ :warehouse_id, :coffee_state, :counted_at, :counted_gross, :counted_sacks, :reason, :reason_detail, :observations ])
      end
  end
end
