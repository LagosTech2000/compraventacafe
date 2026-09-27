module Trading
  class ZonesController < ApplicationController
    before_action :set_zone, only: %i[ edit update ]

    def index
      authorize Zone
      @filter = ZoneFilter.new(params)
      @zones, @next_page = @filter.results(policy_scope(Zone))
    end

    def new
      @zone = authorize Zone.new
    end

    def create
      @zone = authorize Zone.new(zone_params)

      if @zone.save
        close_modal_with notice: t(".success"), fallback: trading_zones_path,
                         event: "zone:created", detail: { id: @zone.id, name: @zone.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @zone.update(zone_params)
        close_modal_with notice: t(".success"), fallback: trading_zones_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_zone
        @zone = authorize Zone.find(params[:id])
      end

      def zone_params
        params.expect(zone: [ :name ])
      end
  end
end
