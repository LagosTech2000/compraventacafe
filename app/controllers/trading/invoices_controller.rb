module Trading
  class InvoicesController < ApplicationController
    before_action :set_invoice, only: %i[ show ]

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
        @purchases = @producer.purchases.owned.uninvoiced.includes(:loan_payments).newest_first
        @settlement = PurchaseLoanSettlement.new(purchase: @purchases.first, user: Current.user) if @purchases.any?
        load_batches
      else
        # Producers whose latest uninvoiced purchase is most recent come first.
        @producers_to_invoice = Producer.joins(:purchases).merge(Purchase.owned.uninvoiced).group(:id)
                                        .order(Arel.sql("MAX(purchases.purchased_at) DESC, MAX(purchases.id) DESC"))
                                        .includes(:person)
      end
    end

    def create
      authorize Invoice
      producer = Producer.find(params.expect(:producer_id))
      result = InvoiceIssuer.new(producer:, user: Current.user, **issue_params, **batch_params).call

      if result.success?
        redirect_to trading_invoice_path(result.invoice), notice: t(".success")
      else
        @producer = producer
        @invoice = result.invoice
        @purchases = producer.purchases.owned.uninvoiced.includes(:loan_payments).newest_first
        load_batches
        render :new, status: :unprocessable_content
      end
    end

    private
      # The lots an invoice can go in from here (Fernando, 2026-11-13): the
      # user's, with room under their limit, neither sold nor processed;
      # nothing when they can't add invoices to lots.
      def load_batches
        @batches = []
        @shares = []
        @lot_id = params.dig(:invoice, :coffee_batch_id)
        @batch_percent = params.dig(:invoice, :batch_percent) || 100
        return unless policy(CoffeeBatchInvoice.new).create?

        lots = policy_scope(CoffeeBatch).includes(:warehouse, :shipment).newest_first.to_a
        lots.reject! { it.shipment&.sold? || it.processed? }
        totals = CoffeeBatch::Totals.by_batch(lots.map(&:id))
        @batches = lots.filter_map do |lot|
          room = lot.gross_limit.to_d - totals.fetch(lot.id, CoffeeBatch::Totals.zero).gross
          [ lot, room ] if room.positive?
        end
      end

      # The lot chosen, checked like adding an invoice from the lot.
      def batch_params
        id = params.dig(:invoice, :coffee_batch_id).presence
        return {} unless id

        lot = policy_scope(CoffeeBatch).find(id)
        authorize CoffeeBatchInvoice.new(coffee_batch: lot), :create?
        { coffee_batch: lot, batch_percent: params.dig(:invoice, :batch_percent) }
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
