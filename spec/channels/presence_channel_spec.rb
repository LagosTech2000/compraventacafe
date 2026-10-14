require "rails_helper"

# Every signed-in page keeps a PresenceChannel subscription (presence.js).
RSpec.describe PresenceChannel, type: :channel do
  let(:user) { create(:user) }

  before { stub_connection current_user: user }

  it "marks the user online while subscribed" do
    subscribe
    expect(subscription).to be_confirmed
    expect(Presence.online_user_ids).to eq([ user.id ])

    unsubscribe
    expect(Presence.online_user_ids).to be_empty
  end
end
