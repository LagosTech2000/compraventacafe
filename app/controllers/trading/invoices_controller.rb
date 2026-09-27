module Trading
  class InvoicesController < ApplicationController
    before_action :set_invoice, only: %i[ show update ]

    def index
      authorize Invoice
      @filter = InvoiceFilter.new(params)
      @invoices, @next_page = @filter.results(policy_scope(Invoice))
    end

    def show
    end

    def new
      authorize Invoice
      @producer = Producer.find_by(id: params[:producer_id])

      if @producer
        @invoice = @producer.invoices.build(payment_status: "pending")
        @purchases = @producer.purchases.uninvoiced.chronological
      else
        @producers_to_invoice = Producer.where(id: Purchase.uninvoiced.select(:producer_id)).includes(:person).alphabetical
      end
    end

    def create
      authorize Invoice
      producer = Producer.find(params.expect(:producer_id))
      result = InvoiceIssuer.new(producer:, user: Current.user, **issue_params).call

      if result.success?
        redirect_to trading_invoice_path(result.invoice), notice: t(".success")
      else
        @producer = producer
        @invoice = result.invoice
        @purchases = producer.purchases.uninvoiced.chronological
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @invoice.mark_paid(**payment_params)
        close_modal_with notice: t(".success"), fallback: trading_invoice_path(@invoice)
      else
        render :show, status: :unprocessable_content
      end
    end

    private
      def set_invoice
        @invoice = authorize Invoice.includes(:created_by, purchases: :zone, producer: [ :person, :zone ]).find(params[:id])
      end

      def issue_params
        permitted = params.expect(invoice: [ :payment_status, :payment_method, :paid_on, purchase_ids: [] ])
        {
          purchase_ids: permitted[:purchase_ids], payment_status: permitted[:payment_status],
          payment_method: permitted[:payment_method], paid_on: permitted[:paid_on]
        }
      end

      def payment_params
        permitted = params.expect(invoice: [ :payment_method, :paid_on ])
        { method: permitted[:payment_method], on: permitted[:paid_on].presence || Time.zone.today }
      end
  end
end
