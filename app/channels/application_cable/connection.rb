module ApplicationCable
  # Live updates (LiveUpdates) only reach signed-in, active users: the same
  # session cookie as the pages, and an inactive user is turned away.
  #
  # A fingerprint bridge (Fernando, 2026-11-14) connects with its station's
  # token instead (Authorization: Bearer), and only to its own channel. A
  # browser linked to a station (its signed cookie) hears what that reader
  # identifies (FingerprintChannel).
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_session, :fingerprint_station, :linked_station_id

    def connect
      set_current_user || set_fingerprint_station || reject_unauthorized_connection
    end

    private
      def set_current_user
        if (session = Session.joins(:user).merge(User.active).find_by(id: cookies.signed[:session_id]))
          self.current_session = session
          self.current_user = session.user
          self.linked_station_id = cookies.signed[FingerprintStation::COOKIE]
          true
        end
      end

      def set_fingerprint_station
        token = request.headers["Authorization"].to_s[/\ABearer\s+(\S+)\z/, 1]
        self.fingerprint_station = FingerprintStation.authenticate(token)
      end
  end
end
