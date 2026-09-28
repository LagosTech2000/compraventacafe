module Trading
  class ProducersController < ApplicationController
    before_action :set_producer, only: %i[ show edit update ]

    def index
      authorize Producer
      @filter = ProducerFilter.new(params)
      @producers, @next_page = @filter.results(policy_scope(Producer))
    end

    def show
      @uninvoiced_purchases = @producer.purchases.uninvoiced.newest_first
      @recent_invoices = @producer.invoices.newest_first.limit(10)
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
