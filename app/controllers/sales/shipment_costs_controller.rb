module Sales
  # Costs of a shipment registered from it (Fernando, 2026-11-12), as a
  # process's: each with how it was charged and the account it went out of.
  class ShipmentCostsController < ApplicationController
    before_action :set_shipment

    def new
      @cost = authorize @shipment.costs.new(pricing: "total", weight_side: "origin", weight_kind: "net", quintal_pounds: 100,
                                            paid_on: Time.zone.today)
    end

    def create
      @cost = authorize @shipment.costs.new(cost_params.merge(created_by: Current.user))

      if @cost.save
        close_modal_with notice: t(".success", amount: helpers.format_money(@cost.amount)), fallback: sales_shipment_path(@shipment)
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      cost = authorize @shipment.costs.find(params[:id])
      cost.destroy!
      redirect_to sales_shipment_path(@shipment, anchor: "shipment-cost"), notice: t(".success"), status: :see_other
    end

    private
      def set_shipment
        @shipment = Shipment.find(params[:shipment_id])
      end

      def cost_params
        params.expect(shipment_cost: [ :concept, :description, :pricing, :weight_side, :weight_kind, :quintal_pounds, :unit_price, :amount,
                                       :paid_on, :payment_method, :money_account_id, :receipt_upload ])
      end
  end
end
