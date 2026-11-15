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

    # An administrator's edit (Fernando, 2026-11-12): date, observations and
    # which purchases it has; each purchase is edited from its own form.
    # And its lot (Fernando, 2026-11-13: «en editar factura también»).
    def edit
      @purchases = editable_purchases
      load_batches(invoice: @invoice)
    end

    def update
      permitted = params.expect(invoice: [ :issued_on, :observations, :coffee_batch_id, :batch_percent, :lot_was, purchase_ids: [] ])
      Invoice.transaction do
        @invoice.revise!(issued_on: permitted[:issued_on], observations: permitted[:observations], purchase_ids: permitted[:purchase_ids])
        change_lot(permitted)
      end
      redirect_to trading_invoice_path(@invoice), notice: t(".success")
    rescue ActiveRecord::RecordInvalid => error
      if error.record.is_a?(CoffeeBatchInvoice)
        error.record.errors.each { @invoice.errors.add(:base, t("trading.invoices.lot_fields.error", batch: error.record.coffee_batch.label, message: it.full_message)) }
      end
      @purchases = editable_purchases
      load_batches(invoice: @invoice)
      render :edit, status: :unprocessable_content
    end

    private
      # The lots an invoice can go in from here (Fernando, 2026-11-13): the
      # user's, with room under their limit, not on a sold shipment (unless
      # an administrator); nothing when they can't add invoices to lots.
      # When editing, what the invoice itself took of a lot counts as room,
      # and its lot shows with its percent (or its lots, when split).
      def load_batches(invoice: nil)
        @batches = []
        @shares = invoice ? invoice.batch_invoices.includes(:coffee_batch).order(:id).to_a : []
        share = @shares.first if @shares.one?
        @lot_id = params.dig(:invoice, :coffee_batch_id) || share&.coffee_batch_id
        @batch_percent = params.dig(:invoice, :batch_percent) || share&.percent || 100
        @lot_was = invoice && "#{share&.coffee_batch_id}:#{share&.percent&.to_d}"
        return unless policy(CoffeeBatchInvoice.new).create?

        lots = policy_scope(CoffeeBatch).includes(:warehouse, :shipment).newest_first.to_a
        lots.reject! { it.shipment&.sold? && it.id != share&.coffee_batch_id } unless Current.user.admin?
        totals = CoffeeBatch::Totals.by_batch(lots.map(&:id))
        @batches = lots.filter_map do |lot|
          room = lot.gross_limit.to_d - totals.fetch(lot.id, CoffeeBatch::Totals.zero).gross
          room += share.gross_weight.to_d if share&.coffee_batch_id == lot.id
          [ lot, room ] if room.positive?
        end
      end

      # Only when the lot or its percent changed: untouched, the lot keeps
      # its pounds as the purchases change (CoffeeBatchInvoice.rebase!).
      def change_lot(permitted)
        return unless permitted.key?(:coffee_batch_id)

        lot_id = permitted[:coffee_batch_id].presence
        percent = lot_id && (permitted[:batch_percent].presence || 100).to_d
        return if "#{lot_id}:#{percent}" == permitted[:lot_was].to_s

        lot = lot_id && policy_scope(CoffeeBatch).find(lot_id)
        authorize CoffeeBatchInvoice.new(coffee_batch: lot), :create? if lot
        CoffeeBatchInvoice.assign!(invoice: @invoice, batch: lot, percent:, user: Current.user)
      end

      # The lot chosen, checked like adding an invoice from the lot.
      def batch_params
        id = params.dig(:invoice, :coffee_batch_id).presence
        return {} unless id

        lot = policy_scope(CoffeeBatch).find(id)
        authorize CoffeeBatchInvoice.new(coffee_batch: lot), :create?
        { coffee_batch: lot, batch_percent: params.dig(:invoice, :batch_percent) }
      end

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
