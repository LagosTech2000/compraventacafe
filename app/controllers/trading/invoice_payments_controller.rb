module Trading
  # Payments of an invoice to its producer ("abonos"): registered from the
  # invoice in a modal, each with its printable receipt. Only the latest one
  # can be removed.
  class InvoicePaymentsController < ApplicationController
    before_action :set_invoice

    def new
      @payment = authorize @invoice.payments.build(paid_on: Time.zone.today, amount: @invoice.balance_due)
    end

    # Its receipt: original and copy, printed on one sheet.
    def show
      @payment = authorize @invoice.payments.find(params[:id])
    end

    def create
      @payment = authorize @invoice.payments.build(payment_params.merge(created_by: Current.user))

      if @payment.save
        # Back on the invoice, with the new payment's receipt open to print it.
        receipt = trading_invoice_path(@invoice, receipt: @payment.id)
        close_modal_with notice: t(".success"), fallback: receipt, visit: receipt
      else
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      payment = authorize @invoice.payments.find(params[:id])
      payment.destroy!
      close_modal_with notice: t(".success"), fallback: trading_invoice_path(@invoice)
    end

    private
      def set_invoice
        @invoice = Invoice.includes(payments: :created_by, purchases: :loan_payments, producer: :person).find(params[:invoice_id])
      end

      def payment_params
        params.expect(invoice_payment: [ :paid_on, :amount, :payment_method ])
      end
  end
end
