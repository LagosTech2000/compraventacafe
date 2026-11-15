module Administration
  # The PCs with a fingerprint reader (Fernando, 2026-11-14). Created from
  # that PC's browser, which is linked to it (a signed cookie: what the
  # reader identifies opens there); the page shows a one-time code to type
  # in the bridge. Another browser of the same PC is linked with «Usar en
  # este navegador». Deactivating it cuts the bridge and the browsers.
  class FingerprintStationsController < ApplicationController
    before_action :set_station, only: %i[ show destroy link pairing ]

    def index
      authorize FingerprintStation
      @stations = FingerprintStation.includes(:created_by).order(active: :desc, name: :asc)
      @linked_id = linked_station_id
    end

    def show
      @linked = linked_station_id == @station.id
    end

    def new
      @station = authorize FingerprintStation.new
    end

    def create
      @station = authorize FingerprintStation.new(name: params.dig(:fingerprint_station, :name), created_by: Current.user)
      if @station.save
        @station.start_pairing!
        link_this_browser(@station)
        flash[:pairing_code] = @station.pairing_code
        redirect_to administration_fingerprint_station_path(@station), notice: t(".success")
      else
        render :new, status: :unprocessable_content
      end
    end

    # A new one-time code for the bridge.
    def pairing
      @station.start_pairing!
      flash[:pairing_code] = @station.pairing_code
      redirect_to administration_fingerprint_station_path(@station), notice: t(".success")
    end

    # This browser shows what the station's reader identifies.
    def link
      link_this_browser(@station)
      redirect_to administration_fingerprint_station_path(@station), notice: t(".success")
    end

    def destroy
      @station.deactivate!
      cookies.delete(FingerprintStation::COOKIE) if linked_station_id == @station.id
      redirect_to administration_fingerprint_stations_path, notice: t(".success"), status: :see_other
    end

    private
      def set_station
        @station = authorize FingerprintStation.find(params[:id])
      end

      def linked_station_id = cookies.signed[FingerprintStation::COOKIE]

      def link_this_browser(station)
        cookies.signed.permanent[FingerprintStation::COOKIE] = { value: station.id, httponly: true, same_site: :lax }
      end
  end
end
