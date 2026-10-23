module Farms
  class FarmsController < ApplicationController
    include FarmParams
    before_action :set_farm, only: %i[ show edit update ]

    def index
      authorize Farm
      @filter = FarmFilter.new(params)
      @farms, @next_page = @filter.results(policy_scope(Farm))
    end

    # The farm and its payrolls, with what each one has cost, what was
    # bought from it, what was picked and its yield per land (FarmProfile).
    def show
      @filter = PayrollFilter.new(params)
      @payrolls, @next_page = @filter.results(policy_scope(Payroll).where(farm: @farm))
      @count = @filter.apply(policy_scope(Payroll).where(farm: @farm)).unscope(:order, :includes).count
      @all_payrolls = @farm.payrolls
      @profile = FarmProfile.new(@farm)
    end

    def new
      # From a purchase: a farm of that producer.
      @farm = authorize Farm.new(producer: Producer.find_by(id: params[:producer_id]))
    end

    def create
      @farm = authorize Farm.new(farm_params)

      if @farm.save
        close_modal_with notice: t(".success"), fallback: farms_farm_path(@farm),
                         event: "farm:created", detail: farm_picker_detail(@farm)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      # From a purchase (picker=1, «Completar datos»): the form stays and
      # learns what the farm still misses.
      if @farm.update(farm_params)
        close_modal_with notice: t(".success"), fallback: farms_farm_path(@farm),
                         event: "farm:updated", detail: farm_picker_detail(@farm)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_farm
        @farm = authorize Farm.find(params[:id])
      end
  end
end
