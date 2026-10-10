module Loans
  class SuppliesController < ApplicationController
    before_action :set_supply, only: %i[ edit update ]

    def index
      authorize Supply
      @filter = SupplyFilter.new(params)
      @supplies, @next_page = @filter.results(policy_scope(Supply))
    end

    def new
      @supply = authorize Supply.new
    end

    def create
      @supply = authorize Supply.new(supply_params)

      if @supply.save
        close_modal_with notice: t(".success"), fallback: loans_supplies_path,
                         event: "supply:created", detail: { id: @supply.id, **@supply.picker_data }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @supply.update(supply_params)
        close_modal_with notice: t(".success"), fallback: loans_supplies_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_supply
        @supply = authorize Supply.find(params[:id])
      end

      def supply_params
        params.expect(supply: [ :name, :unit, :default_price, :active ])
      end
  end
end
