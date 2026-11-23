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

      if settling? ? save_invoiced_and_paid : @purchase.save
        # On the page: back to an empty form, with the saved purchase open in
        # the modal. In a modal: closes it and refreshes the page behind.
        notice = t(".success", producer: @purchase.producer.full_name)
        if (zone = @purchase.zone_given_to_producer)
          notice = "#{notice} #{t(".zone_given", zone: zone.name, producer: @purchase.producer.full_name)}"
        end
        if !@purchase.invoice && (owed = owed_with_coffee(@purchase))
          notice = "#{notice} #{t(".owes", amount: helpers.format_money(owed))}"
        end
        notice = "#{notice} #{t(".settled", number: @purchase.invoice.display_number)}" if @purchase.invoice
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
      # What the producer owes in loans when this purchase's coffee can pay
      # it and the user can do it (pago con café); nil otherwise.
      def owed_with_coffee(purchase)
        return unless policy([ :loans, :coffee_collection ]).settle?

        loans = purchase.producer.person.loans.unpaid.includes(:payments)
        loans.sum { it.balance.total_owed }.then { it.positive? ? it : nil }
      end

      # «Guardar, facturar y pagar» (Fernando, 2026-11-18): they buy, invoice
      # and pay at once. The purchase, its invoice and a payment for all of
      # it are saved together or none (InvoiceIssuer's rules).
      def settling?
        params[:settle_now].present? && policy(Invoice).create?
      end

      def save_invoiced_and_paid
        settle = params.fetch(:settle, {}).permit(:payment_method, :money_account_id)
        Purchase.transaction do
          raise ActiveRecord::Rollback unless @purchase.save

          result = InvoiceIssuer.new(producer: @purchase.producer, purchase_ids: [ @purchase.id ], user: Current.user, payment_status: "paid",
                                     payment_method: settle[:payment_method], money_account_id: settle[:money_account_id]).call
          next @purchase.reload if result.success?

          result.invoice.errors.full_messages.each { @purchase.errors.add(:base, it) }
          raise ActiveRecord::Rollback
        end.tap { |saved| restore_new_purchase unless saved }
      end

      # After a rollback the purchase looks saved: back to a new one, with
      # what was written and its errors.
      def restore_new_purchase
        errors = @purchase.errors.dup
        @purchase = Purchase.new(purchase_params.merge(created_by: Current.user))
        @purchase.valid?
        errors.each { |error| @purchase.errors.add(error.attribute, error.message) unless @purchase.errors.added?(error.attribute, error.message) }
      end

      def set_purchase
        @purchase = authorize Purchase.find(params[:id])
      end

      def purchase_params
        params.expect(purchase: [ :purchased_at, :producer_id, :zone_id, :farm_id, :farm_plot_id, :hauler_choice, :vehicle_id, :warehouse_id, :coffee_state, :common_coffee, :weight_mode, :gross_weight,
                                  :humidity_percent, :damage_percent, :yield_factor, :price_per_pound, :observations, :lock_version, damage_types: [],
                                  weighings_attributes: [ [ :id, :gross_weight, :sacks, :_destroy ] ] ])
      end
  end
end
