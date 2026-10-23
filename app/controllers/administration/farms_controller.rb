module Administration
  # Every farm, of the business or of a producer, from Administración
  # (Fernando, 2026-10-14), with its permissions (Administration::FarmPolicy).
  # A farm that purchases or payrolls name is deactivated, not deleted.
  class FarmsController < ApplicationController
    include FarmParams
    before_action :set_farm, only: %i[ show edit update destroy ]

    def index
      authorize [ :administration, Farm ]
      @filter = FarmFilter.new(params)
      @farms, @next_page = @filter.results(policy_scope([ :administration, Farm ]))
    end

    def show
    end

    def new
      @farm = authorize [ :administration, Farm.new ]
    end

    def create
      @farm = Farm.new(farm_params)
      authorize [ :administration, @farm ]

      if @farm.save
        close_modal_with notice: t(".success"), fallback: administration_farms_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @farm.update(farm_params)
        close_modal_with notice: t(".success"), fallback: administration_farms_path,
                         event: "farm:updated", detail: farm_picker_detail(@farm)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @farm.destroy
        close_modal_with notice: t(".success"), fallback: administration_farms_path
      else
        redirect_back_or_to administration_farms_path, alert: t(".in_use")
      end
    end

    private
      def set_farm
        @farm = Farm.find(params[:id])
        authorize [ :administration, @farm ]
      end
  end
end
