module Trading
  class PurchasesController < ApplicationController
    include DateParam

    before_action :set_purchase, only: %i[ show edit update destroy ]

    def index
      authorize Purchase
      @date = date_param
      @daily_close = DailyClose.new(@date)
    end

    def show
    end

    def new
      producer = Producer.find_by(id: params[:producer_id])
      @purchase = authorize Purchase.new(
        purchased_on: Time.zone.today, coffee_state: "wet_parchment",
        humidity_percent: PurchaseDefaults::HUMIDITY_PERCENT, producer: producer, zone: producer&.zone
      )
    end

    def create
      @purchase = authorize Purchase.new(purchase_params.merge(created_by: Current.user))

      if @purchase.save
        redirect_to new_trading_purchase_path, notice: t(".success", producer: @purchase.producer.full_name)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @purchase.update(purchase_params)
        redirect_to trading_purchases_path(date: @purchase.purchased_on), notice: t(".success")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @purchase.destroy!
      redirect_to trading_purchases_path(date: @purchase.purchased_on), notice: t(".success"), status: :see_other
    end

    private
      def set_purchase
        @purchase = authorize Purchase.find(params[:id])
      end

      def purchase_params
        params.expect(purchase: [ :purchased_on, :producer_id, :zone_id, :coffee_state,
                                  :gross_weight, :humidity_percent, :price_per_pound, :observations ])
      end
  end
end
