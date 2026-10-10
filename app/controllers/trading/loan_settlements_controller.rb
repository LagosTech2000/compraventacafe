module Trading
  # Pays the producer's loans with the money of a purchase ("pago con café").
  class LoanSettlementsController < ApplicationController
    before_action :set_purchase

    def new
      # The date can be changed on the form: it reloads with the debt on that date.
      @settlement = authorize PurchaseLoanSettlement.new(purchase: @purchase, user: Current.user, paid_on: params[:paid_on])
    end

    def create
      @settlement = authorize PurchaseLoanSettlement.new(purchase: @purchase, user: Current.user, **settlement_params)

      if @settlement.save
        close_modal_with notice: t(".success", count: @settlement.payments.size, amount: helpers.format_money(@settlement.total)),
                         fallback: trading_purchase_path(@purchase)
      else
        render :new, status: :unprocessable_content
      end
    end

    private
      def set_purchase
        @purchase = Purchase.find(params[:purchase_id])
      end

      def settlement_params
        permitted = params.expect(purchase_loan_settlement: [ :paid_on, :observations, amounts: {} ])
        { paid_on: permitted[:paid_on], observations: permitted[:observations], amounts: permitted[:amounts].to_h }
      end
  end
end
