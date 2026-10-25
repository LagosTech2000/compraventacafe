module Trading
  # Carreros (Hauler): their commission percent and can price, the purchases
  # they hauled with their commissions, what they are owed and the payments
  # of it, each with its receipt.
  class HaulersController < ApplicationController
    before_action :set_hauler, only: %i[ show edit update ]

    def index
      authorize Hauler
      @filter = HaulerFilter.new(params)
      @haulers, @next_page = @filter.results(policy_scope(Hauler))
    end

    def show
      @filter = HaulerPurchaseFilter.new(params)
      @purchases, @next_page = @filter.results(@hauler.purchases)
      @payments = @hauler.payments.includes(:created_by).reverse
    end

    def new
      @hauler = authorize Hauler.new
      @hauler.build_person
    end

    def create
      @hauler = authorize Hauler.new(hauler_params)

      if @hauler.save
        close_modal_with notice: t(".success"), fallback: trading_hauler_path(@hauler),
                         event: "hauler:created",
                         detail: { id: @hauler.id, label: @hauler.full_name, name: @hauler.full_name,
                                   data: { pricePerPound: @hauler.price_per_pound.to_s } }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @hauler.update(hauler_params)
        close_modal_with notice: t(".success"), fallback: trading_hauler_path(@hauler)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_hauler
        @hauler = authorize Hauler.find(params[:id])
      end

      def hauler_params
        params.expect(hauler: [
          :price_per_pound, :active,
          person_attributes: [ :id, :first_names, :last_names, :dni, :rtn, :phone, :email, :civil_status, :nationality, :zone_id,
                               :department_id, :municipality_id, :address_line, :latitude, :longitude,
                               :photo_upload, :remove_photo, :client_role, :collaborator_role ]
        ])
      end
  end
end
