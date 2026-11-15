module Trading
  # Voiding a purchase invoice (Fernando, 2026-11-12): administrators only,
  # even paid, with a reason. Its purchases are voided and its payments
  # removed (Invoice#void!).
  class InvoiceVoidsController < ApplicationController
    before_action :set_invoice

    def new
    end

    def create
      @invoice.void!(Current.user, reason: params.dig(:invoice, :void_reason))
      close_modal_with notice: t(".success", number: @invoice.display_number), fallback: trading_invoice_path(@invoice)
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_content
    end

    private
      def set_invoice
        @invoice = authorize Invoice.includes(:payments, purchases: %i[loan_payments hauler farm producer], producer: :person).find(params[:invoice_id]), :void?
      end
  end
end
