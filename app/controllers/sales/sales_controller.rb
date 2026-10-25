module Sales
  # Sales: shipments of one buyer, weighed at destination, charged on the
  # buyer's net (SaleIssuer). Never edited: collected in payments or voided.
  class SalesController < ApplicationController
    before_action :set_sale, only: %i[ show void ]

    def index
      authorize Sale
      @filter = SaleFilter.new(params)
      @sales, @next_page = @filter.results(policy_scope(Sale))
      @summary = SaleSummary.new(@filter.apply(policy_scope(Sale)))
    end

    def show
    end

    def new
      authorize Sale
      @buyer = Buyer.find_by(id: params[:buyer_id])

      if @buyer
        @sale = @buyer.sales.build(sold_on: Time.zone.today, price_unit: "quintal", payment_status: "pending")
        @shipments = @buyer.shipments.unsold.newest_first
      else
        # Buyers whose latest shipment ready to sell is most recent come first.
        @buyers_to_sell = Buyer.joins(:shipments).merge(Shipment.unsold).group(:id)
                               .order(Arel.sql("MAX(shipments.departed_at) DESC, buyers.id DESC"))
                               .select("buyers.*", "COUNT(shipments.id) AS shipments_count",
                                       "SUM(shipments.destination_net_weight) AS net_total")
      end
    end

    def create
      authorize Sale
      buyer = Buyer.find(params.expect(:buyer_id))
      result = SaleIssuer.new(buyer:, user: Current.user, **issue_params).call

      if result.success?
        redirect_to sales_sale_path(result.sale), notice: t(".success", number: result.sale.display_number)
      else
        @buyer = buyer
        @sale = result.sale
        @shipments = buyer.shipments.unsold.newest_first
        render :new, status: :unprocessable_content
      end
    end

    def void
      authorize @sale, :void?
      @sale.void!(Current.user, reason: params.dig(:sale, :void_reason))
      redirect_to sales_sale_path(@sale), notice: t(".success")
    end

    private
      def set_sale
        @sale = Sale.includes(:buyer, :created_by, :voided_by, payments: :created_by, lines: :shipment).find(params[:id])
        authorize @sale unless action_name == "void"
      end

      def issue_params
        permitted = params.expect(sale: [ :sold_on, :price_unit, :unit_price, :buyer_document_number, :observations,
                                          :payment_status, :payment_method, :paid_on, :amount, :money_account_id, :advance_amount, shipment_ids: [] ])
        {
          shipment_ids: permitted[:shipment_ids],
          sale: permitted.slice(:sold_on, :price_unit, :unit_price, :buyer_document_number, :observations).to_h,
          payment_status: permitted[:payment_status], payment_method: permitted[:payment_method],
          paid_on: permitted[:paid_on], amount: permitted[:amount], money_account_id: permitted[:money_account_id],
          advance_amount: permitted[:advance_amount]
        }
      end
  end
end
