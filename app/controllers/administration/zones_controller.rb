module Administration
  # Zones from Administración (Fernando, 2026-10-14), with its permissions
  # (Administration::ZonePolicy). A zone that people or purchases name stays.
  class ZonesController < ApplicationController
    before_action :set_zone, only: %i[ edit update destroy ]

    def index
      authorize [ :administration, Zone ]
      @filter = ZoneFilter.new(params)
      @zones, @next_page = @filter.results(policy_scope([ :administration, Zone ]))
      @people = Person.where(zone_id: @zones.map(&:id)).group(:zone_id).count
      @purchases = Purchase.active.where(zone_id: @zones.map(&:id)).group(:zone_id).count
    end

    def new
      @zone = authorize [ :administration, Zone.new ]
    end

    def create
      @zone = Zone.new(zone_params)
      authorize [ :administration, @zone ]

      if @zone.save
        close_modal_with notice: t(".success"), fallback: administration_zones_path,
                         event: "zone:created", detail: { id: @zone.id, name: @zone.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @zone.update(zone_params)
        close_modal_with notice: t(".success"), fallback: administration_zones_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @zone.destroy
        close_modal_with notice: t(".success"), fallback: administration_zones_path
      else
        redirect_back_or_to administration_zones_path, alert: t(".in_use")
      end
    end

    private
      def set_zone
        @zone = Zone.find(params[:id])
        authorize [ :administration, @zone ]
      end

      def zone_params
        params.expect(zone: [ :name ])
      end
  end
end
