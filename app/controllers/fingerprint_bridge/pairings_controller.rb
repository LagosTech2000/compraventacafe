module FingerprintBridge
  # The bridge types the one-time code of its station and gets its token.
  class PairingsController < BaseController
    rate_limit to: 10, within: 10.minutes, by: -> { request.remote_ip }, with: -> { head :too_many_requests }

    def create
      station, token = FingerprintStation.pair!(params[:code])
      return head(:unprocessable_content) unless station

      render json: { token:, station: station.name }
    end
  end
end
