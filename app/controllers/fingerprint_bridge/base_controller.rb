module FingerprintBridge
  # What the fingerprint bridge of a PC asks over HTTPS (Fernando,
  # 2026-11-14): no session; the station's token, except to pair.
  class BaseController < ActionController::API
    private
      def authenticate_station!
        token = request.authorization.to_s[/\ABearer\s+(\S+)\z/, 1]
        @station = FingerprintStation.authenticate(token)
        head :unauthorized unless @station
      end
  end
end
