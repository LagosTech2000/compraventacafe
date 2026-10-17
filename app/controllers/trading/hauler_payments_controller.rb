module Trading
  # Payments of a hauler's commissions: registered from the hauler's page in
  # a modal, each with its printable receipt. Only the latest one can be
  # removed.
  class HaulerPaymentsController < ApplicationController
    before_action :set_hauler

    def new
      @payment = authorize @hauler.payments.build(paid_on: Time.zone.today, amount: (@hauler.balance if @hauler.balance.positive?))
    end

    # Its receipt: original and copy, each printed on its own sheet.
    def show
      @payment = authorize @hauler.payments.find(params[:id])
    end

    # The hauler is locked meanwhile: two payments at once cannot pass
    # what they are owed.
    def create
      @payment = authorize @hauler.payments.build(payment_params.merge(created_by: Current.user))

      if Hauler.transaction { @hauler.lock! && @payment.save }
        # Back on the hauler, with the new payment's receipt open to print it.
        receipt = trading_hauler_path(@hauler, receipt: @payment.id)
        close_modal_with notice: t(".success"), fallback: receipt, visit: receipt
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      payment = authorize @hauler.payments.find(params[:id])
      payment.destroy!
      close_modal_with notice: t(".success"), fallback: trading_hauler_path(@hauler)
    end

    private
      def set_hauler
        @hauler = Hauler.includes(:person).find(params[:hauler_id])
      end

      def payment_params
        params.expect(hauler_payment: [ :paid_on, :amount, :payment_method, :observations ])
      end
  end
end
