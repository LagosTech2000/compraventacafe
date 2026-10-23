module Trading
  class PurchasesController < ApplicationController
    before_action :set_purchase, only: %i[ show edit update destroy void ]

    def index
      authorize Purchase
      @filter = PurchaseFilter.new(params)
      filtered = @filter.apply(policy_scope(Purchase))
      @summary = PurchaseSummary.new(filtered.active)
      @purchases, @next_page = @filter.results(policy_scope(Purchase))
    end

    def show
      @loan_payments = @purchase.loan_payments.includes(:loan).chronological
      @settlement = PurchaseLoanSettlement.new(purchase: @purchase, user: Current.user)
    end

    def new
      producer = Producer.find_by(id: params[:producer_id])
      @purchase = authorize Purchase.new(
        purchased_at: Time.current.change(sec: 0), coffee_state: PurchaseDefaults::COFFEE_STATE,
        **PurchaseDefaults.inputs_for(PurchaseDefaults::COFFEE_STATE), producer: producer, zone: producer&.zone
      )
    end

    def create
      @purchase = authorize Purchase.new(purchase_params.merge(created_by: Current.user))

      if @purchase.save
        # On the page: back to an empty form, with the saved purchase open in
        # the modal. In a modal: closes it and refreshes the page behind.
        notice = t(".success", producer: @purchase.producer.full_name)
        if (zone = @purchase.zone_given_to_producer)
          notice = "#{notice} #{t(".zone_given", zone: zone.name, producer: @purchase.producer.full_name)}"
        end
        close_modal_with notice:,
                         fallback: new_trading_purchase_path(detail: @purchase.id)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @purchase.update(purchase_params)
        close_modal_with notice: t(".success"), fallback: trading_purchase_path(@purchase)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @purchase.destroy!
      close_modal_with notice: t(".success"), fallback: trading_purchases_path
    end

    # Voided from its detail (modal) or from a list (the page it was on).
    def void
      @purchase.void!(Current.user)

      if modal_request?
        close_modal_with notice: t(".success"), fallback: trading_purchases_path
      else
        redirect_back_or_to trading_purchases_path, notice: t(".success")
      end
    end

    private
      def set_purchase
        @purchase = authorize Purchase.find(params[:id])
      end

      def purchase_params
        params.expect(purchase: [ :purchased_at, :producer_id, :zone_id, :farm_id, :hauler_id, :coffee_state, :weight_mode, :gross_weight,
                                  :humidity_percent, :damage_percent, :yield_factor, :price_per_pound, :observations, :lock_version,
                                  weighings_attributes: [ [ :id, :gross_weight, :sacks, :_destroy ] ] ])
      end
  end
end
