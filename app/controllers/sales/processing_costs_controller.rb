module Sales
  # What processing a coffee conversion cost (client, 2026-10-26): each
  # cost with how it was charged and the account it went out of.
  class ProcessingCostsController < ApplicationController
    before_action :set_conversion

    def new
      @cost = authorize @conversion.processing_costs.new(last_terms.merge(paid_on: Time.zone.today))
    end

    def create
      @cost = authorize @conversion.processing_costs.new(cost_params.merge(created_by: Current.user))

      if @cost.save
        close_modal_with notice: t(".success", amount: helpers.format_money(@cost.amount)), fallback: sales_coffee_conversion_path(@conversion)
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      @cost = authorize @conversion.processing_costs.find(params[:id])
      @cost.destroy!
      redirect_back_or_to sales_coffee_conversion_path(@conversion), notice: t(".success"), status: :see_other
    end

    private
      def set_conversion
        @conversion = CoffeeConversion.includes(:processing_site).find(params[:coffee_conversion_id])
      end

      # How this site charged last time: a new cost starts the same way.
      def last_terms
        last = ProcessingCost.joins(:coffee_conversion).where(coffee_conversions: { processing_site_id: @conversion.processing_site_id })
                             .order(created_at: :desc).first if @conversion.processing_site_id
        starting = { pricing: "total", weight_side: "input", weight_kind: "gross", quintal_pounds: 100 }
        return starting unless last

        starting.merge last.slice(:concept, :pricing, :weight_side, :weight_kind, :quintal_pounds, :unit_price, :payment_method, :money_account_id)
            .merge(weight_side: (last.weight_side == "output" && !@conversion.finished? ? "input" : last.weight_side))
            .symbolize_keys.compact
      end

      def cost_params
        params.expect(processing_cost: [ :concept, :description, :pricing, :weight_side, :weight_kind, :quintal_pounds, :unit_price, :amount,
                                         :paid_on, :payment_method, :money_account_id ])
      end
  end
end
