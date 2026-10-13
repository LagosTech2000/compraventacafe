module Farms
  class FarmsController < ApplicationController
    before_action :set_farm, only: %i[ show edit update ]

    def index
      authorize Farm
      @filter = FarmFilter.new(params)
      @farms, @next_page = @filter.results(policy_scope(Farm))
    end

    # The farm and its payrolls, with what each one has cost.
    def show
      @filter = PayrollFilter.new(params)
      @payrolls, @next_page = @filter.results(policy_scope(Payroll).where(farm: @farm))
      @count = @filter.apply(policy_scope(Payroll).where(farm: @farm)).unscope(:order, :includes).count
      @all_payrolls = @farm.payrolls
    end

    def new
      # From a purchase: a farm of that producer.
      @farm = authorize Farm.new(producer: Producer.find_by(id: params[:producer_id]))
    end

    def create
      @farm = authorize Farm.new(farm_params)

      if @farm.save
        close_modal_with notice: t(".success"), fallback: farms_farm_path(@farm),
                         event: "farm:created", detail: { id: @farm.id, name: @farm.name, producer_id: @farm.producer_id }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @farm.update(farm_params)
        close_modal_with notice: t(".success"), fallback: farms_farm_path(@farm)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_farm
        @farm = authorize Farm.find(params[:id])
      end

      def farm_params
        # Its producer can change while no purchase or payroll names the farm (Farm#owner_locked?).
        params.expect(farm: [ :name, :producer_id, :department_id, :municipality_id, :address_line, :observations, :active ])
      end
  end
end
