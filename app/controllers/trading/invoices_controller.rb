module Trading
  class InvoicesController < ApplicationController
    before_action :set_invoice, only: %i[ show edit update ]

    def index
      authorize Invoice
      @filter = InvoiceFilter.new(params)
      @invoices, @next_page = @filter.results(policy_scope(Invoice))
      @count = @filter.apply(policy_scope(Invoice)).unscope(:order, :includes).count
    end

    def show
    end

    def new
      authorize Invoice
      @producer = Producer.find_by(id: params[:producer_id])

      if @producer
        @invoice = @producer.invoices.build(payment_status: "pending")
        @purchases = @producer.purchases.uninvoiced.includes(:loan_payments).newest_first
        @settlement = PurchaseLoanSettlement.new(purchase: @purchases.first, user: Current.user) if @purchases.any?
      else
        # Producers whose latest uninvoiced purchase is most recent come first.
        @producers_to_invoice = Producer.joins(:purchases).merge(Purchase.uninvoiced).group(:id)
                                        .order(Arel.sql("MAX(purchases.purchased_at) DESC, MAX(purchases.id) DESC"))
                                        .includes(:person)
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
        @purchases = producer.purchases.uninvoiced.newest_first
        render :new, status: :unprocessable_content
      end
    end

    # An administrator's edit (Fernando, 2026-11-12): date, observations and
    # which purchases it has; each purchase is edited from its own form.
    def edit
      @purchases = editable_purchases
    end

    def update
      permitted = params.expect(invoice: [ :issued_on, :observations, purchase_ids: [] ])
      @invoice.revise!(issued_on: permitted[:issued_on], observations: permitted[:observations], purchase_ids: permitted[:purchase_ids])
      redirect_to trading_invoice_path(@invoice), notice: t(".success")
    rescue ActiveRecord::RecordInvalid
      @purchases = editable_purchases
      render :edit, status: :unprocessable_content
    end

    private
      # Its purchases and the producer's still uninvoiced, the newest first.
      def editable_purchases
        @invoice.producer.purchases.active.where(invoice_id: [ nil, @invoice.id ]).includes(:loan_payments, :farm).newest_first
      end

      def set_invoice
        @invoice = authorize Invoice.includes(:created_by, payments: :created_by, purchases: [ :zone, :loan_payments ],
                                            producer: [ :person, :zone ]).find(params[:id])
      end

      def issue_params
        permitted = params.expect(invoice: [ :payment_status, :payment_method, :paid_on, :amount, :money_account_id, purchase_ids: [] ])
        {
          purchase_ids: permitted[:purchase_ids], payment_status: permitted[:payment_status],
          payment_method: permitted[:payment_method], paid_on: permitted[:paid_on], amount: permitted[:amount],
          money_account_id: permitted[:money_account_id]
        }
      end
  end
end
