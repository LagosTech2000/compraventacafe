module Trading
  class ProducersController < ApplicationController
    before_action :set_producer, only: %i[ show edit update ]

    def index
      authorize Producer
      @filter = ProducerFilter.new(params)
      @producers, @next_page = @filter.results(policy_scope(Producer))
      @season = Season.current
      @stats = Purchase.active.in_season(@season).where(producer_id: @producers.map(&:id)).group(:producer_id)
        .pluck(:producer_id, Arel.sql("SUM(net_weight)")).to_h
      @last_purchased = Purchase.active.where(producer_id: @producers.map(&:id)).group(:producer_id).maximum(:purchased_at)
    end

    TABS = %w[summary purchases invoices].freeze

    # Header with the pinned figures; a side column with the producer's
    # record, what is pending and their loans; then one tab at a time:
    # summary (seasons and this season's mix), purchases or invoices.
    def show
      @tab = params[:tab].presence_in(TABS) || TABS.first
      @profile = ProducerProfile.new(@producer)
      @credit_account = CreditAccount.new(@producer.person) if policy(Loan).index?

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
                         event: "producer:created", detail: picker_detail
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      # From the purchase form (picker=1) the form stays: it learns the
      # producer's new name, zone, farms and empty details.
      if @producer.update(producer_params)
        close_modal_with notice: t(".success"), fallback: trading_producer_path(@producer),
                         event: "producer:updated", detail: picker_detail
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      # What the purchase form learns of the producer saved in the modal: its
      # label, zone, the farms a purchase can name and the empty details
      # (PickerSearch.data, as the producer search brings them).
      def picker_detail
        @producer.farms.reload
        PickerSearch.data(@producer)
      end

      def set_producer
        @producer = authorize Producer.find(params[:id])
      end

      def producer_params
        params.expect(producer: [
          :kind, :ihcafe_code, :new_farm_name, new_farm_names: [],
          person_attributes: [ :id, :first_names, :last_names, :dni, :rtn, :phone, :email, :zone_id,
                               :department_id, :municipality_id, :address_line, :latitude, :longitude,
                               :photo_upload, :remove_photo, :client_role, :collaborator_role ]
        ])
      end
  end
end
