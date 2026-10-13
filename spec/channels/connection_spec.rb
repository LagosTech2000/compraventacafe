require "rails_helper"

# Live updates reach only signed-in, active users (ApplicationCable::Connection).
RSpec.describe ApplicationCable::Connection, type: :channel do
  it "connects with an active user's session" do
    session = create(:user).sessions.create!
    cookies.signed[:session_id] = session.id
    connect "/cable"
    expect(connection.current_user).to eq(session.user)
  end

  it "rejects visitors without a session and inactive users" do
    expect { connect "/cable" }.to have_rejected_connection

    user = create(:user)
    session = user.sessions.create!
    user.update!(active: false)
    cookies.signed[:session_id] = session.id
    expect { connect "/cable" }.to have_rejected_connection
  end
end
