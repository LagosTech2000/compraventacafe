module Sales
  # Buyers (exporters, processors, others): their record, their shipments
  # and sales, and what they owe.
  class BuyersController < ApplicationController
    before_action :set_buyer, only: %i[ show edit update ]

    TABS = %w[sales shipments payments].freeze

    def index
      authorize Buyer
      @filter = BuyerFilter.new(params)
      @buyers, @next_page = @filter.results(policy_scope(Buyer))
    end

    def show
      @tab = params[:tab].presence_in(TABS) || TABS.first
      @summary = SaleSummary.new(@buyer.sales)
      @shipped = @buyer.shipments.active
      case @tab
      when "sales"
        @filter = BuyerSaleFilter.new(params)
        @sales, @next_page = @filter.results(@buyer.sales)
      when "shipments"
        @filter = BuyerShipmentFilter.new(params)
        @shipments, @next_page = @filter.results(@buyer.shipments)
      when "payments"
        @payments = @buyer.sale_payments.includes(:sale, :created_by).merge(SalePayment.newest_first).to_a
      end
    end

    def new
      @buyer = authorize Buyer.new(kind: "exporter")
    end

    def create
      @buyer = authorize Buyer.new(buyer_params)

      if @buyer.save
        close_modal_with notice: t(".success"), fallback: sales_buyer_path(@buyer),
                         event: "buyer:created", detail: { id: @buyer.id, label: @buyer.name, name: @buyer.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @buyer.update(buyer_params)
        close_modal_with notice: t(".success"), fallback: sales_buyer_path(@buyer)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_buyer
        @buyer = authorize Buyer.find(params[:id])
      end

      def buyer_params
        params.expect(buyer: [ :name, :kind, :rtn, :phone, :email, :contact_name, :department_id, :municipality_id,
                               :address_line, :latitude, :longitude, :observations, :active ])
      end
  end
end
