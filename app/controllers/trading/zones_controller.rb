module Trading
  class ZonesController < ApplicationController
    before_action :set_zone, only: %i[ edit update ]

    def index
      authorize Zone
      @zones = policy_scope(Zone).ordered
    end

    def new
      @zone = authorize Zone.new
    end

    def create
      @zone = authorize Zone.new(zone_params)

      if @zone.save
        redirect_to trading_zones_path, notice: t(".success")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @zone.update(zone_params)
        redirect_to trading_zones_path, notice: t(".success")
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
