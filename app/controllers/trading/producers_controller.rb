module Trading
  class ProducersController < ApplicationController
    before_action :set_producer, only: %i[ show edit update ]

    def index
      authorize Producer
      @filter = ProducerFilter.new(params)
      @producers, @next_page = @filter.results(policy_scope(Producer))
    end

    TABS = %w[purchases invoices info].freeze

    # Pinned figures on top, then one tab at a time: purchases, invoices or
    # the producer's personal data.
    def show
      @tab = params[:tab].presence_in(TABS) || TABS.first
      @season = Season.current
      @season_summary = PurchaseSummary.new(@producer.purchases.active.in_season(@season))
      @all_time_summary = PurchaseSummary.new(@producer.purchases.active)
      @has_uninvoiced = @producer.purchases.uninvoiced.exists?
      @credit_account = CreditAccount.new(@producer.person)

      case @tab
      when "purchases"
        @filter = ProducerPurchaseFilter.new(params)
        @purchases, @next_page = @filter.results(@producer.purchases)
      when "invoices"
        @filter = ProducerInvoiceFilter.new(params)
        @invoices, @next_page = @filter.results(@producer.invoices)
      end
    end

    def new
      @producer = authorize Producer.new(kind: "producer")
      @producer.build_person
    end

    def create
      @producer = authorize Producer.new(producer_params)

      if @producer.save
        close_modal_with notice: t(".success"), fallback: trading_producer_path(@producer),
                         event: "producer:created",
                         detail: { id: @producer.id, label: @producer.picker_label, zone_id: @producer.zone_id }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @producer.update(producer_params)
        close_modal_with notice: t(".success"), fallback: trading_producer_path(@producer)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_producer
        @producer = authorize Producer.find(params[:id])
      end

      def producer_params
        params.expect(producer: [
          :kind, :farm_name, :zone_id,
          person_attributes: [ :id, :first_names, :last_names, :dni, :rtn, :phone, :email,
                               :department_id, :municipality_id, :address_line ]
        ])
      end
  end
end
