module Farms
  # Coffee varieties (Fernando, 2026-11-15): Lempira, IHCAFE 90… the users
  # add, rename and deactivate them; farms and plots choose them.
  class CoffeeVarietiesController < ApplicationController
    before_action :set_variety, only: %i[ edit update ]

    def index
      authorize CoffeeVariety
      @filter = CoffeeVarietyFilter.new(params)
      @varieties, @next_page = @filter.results(policy_scope(CoffeeVariety))
    end

    def new
      @variety = authorize CoffeeVariety.new
    end

    def create
      @variety = authorize CoffeeVariety.new(variety_params)

      if @variety.save
        close_modal_with notice: t(".success"), fallback: farms_coffee_varieties_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @variety.update(variety_params)
        close_modal_with notice: t(".success"), fallback: farms_coffee_varieties_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_variety
        @variety = authorize CoffeeVariety.find(params[:id])
      end

      def variety_params
        params.expect(coffee_variety: [ :name, :active ])
      end
  end
end
