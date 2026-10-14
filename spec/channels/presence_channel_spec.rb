require "rails_helper"

# Every signed-in page keeps a PresenceChannel subscription (presence.js).
RSpec.describe PresenceChannel, type: :channel do
  let(:user) { create(:user) }
  let(:session) { user.sessions.create!(last_seen_at: 1.hour.ago) }

  before { stub_connection current_user: user, current_session: session }

  it "marks the user online while subscribed" do
    subscribe
    expect(subscription).to be_confirmed
    expect(Presence.online_user_ids).to eq([ user.id ])

    unsubscribe
    expect(Presence.online_user_ids).to be_empty
  end

  it "counts closing the tab as the session's last activity" do
    subscribe
    unsubscribe
    expect(session.reload.last_seen_at).to be_within(5.seconds).of(Time.current)
  end
end
