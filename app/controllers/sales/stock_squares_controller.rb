module Sales
  # «Cuadrar inventario» (Fernando, 2026-11-23): every state of every
  # warehouse counted on one page (StockSquare).
  class StockSquaresController < ApplicationController
    def new
      authorize StockCount, :create?
      @square = StockSquare.new
    end

    def create
      authorize StockCount, :create?
      @square = StockSquare.new(entries:, user: Current.user)
      if @square.save
        redirect_to sales_stock_counts_path, notice: t(".success", count: @square.counts.size)
      else
        flash.now[:alert] = t(".nothing") if @square.counts.empty?
        render :new, status: :unprocessable_content
      end
    end

    private
      FIELDS = %i[counted_gross counted_sacks reason reason_detail observations].freeze

      def entries
        keys = Warehouse.active.ids.product(Purchase::COFFEE_STATES).map { |id, state| "#{id}_#{state}" }
        params.fetch(:entries, {}).permit(keys.to_h { [ it, FIELDS ] }).to_h
      end
  end
end
