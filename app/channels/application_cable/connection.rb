module ApplicationCable
  # Live updates (LiveUpdates) only reach signed-in, active users: the same
  # session cookie as the pages, and an inactive user is turned away.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_session

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        if (session = Session.joins(:user).merge(User.active).find_by(id: cookies.signed[:session_id]))
          self.current_session = session
          self.current_user = session.user
        end
      end
  end
end
