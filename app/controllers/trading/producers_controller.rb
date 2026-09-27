module Trading
  class ProducersController < ApplicationController
    before_action :set_producer, only: %i[ show edit update ]

    def index
      authorize Producer
      @query = params[:q].to_s.strip
      producers = policy_scope(Producer).includes(:person, :zone).alphabetical
      producers = producers.merge(Person.search(@query)) if @query.present?
      @producers = producers
    end

    def show
      @uninvoiced_purchases = @producer.purchases.uninvoiced.chronological
      @recent_invoices = @producer.invoices.recent.limit(10)
    end

    def new
      @producer = authorize Producer.new(kind: "producer")
      @producer.build_person
    end

    def create
      @producer = authorize Producer.new(producer_params)

      if @producer.save
        redirect_to after_create_path, notice: t(".success")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @producer.update(producer_params)
        redirect_to trading_producer_path(@producer), notice: t(".success")
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

      # Coming from the purchase form, go back to it with the new producer.
      def after_create_path
        if params[:return_to] == "new_purchase"
          new_trading_purchase_path(producer_id: @producer.id)
        else
          trading_producer_path(@producer)
        end
      end
  end
end
