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

  it "notes the page each tab opens, with its title, as activity" do
    subscribe
    perform :visit, path: "/trading/invoices/12?tab=pagos", title: "  Factura   0012 "

    expect(session.reload).to have_attributes(last_path: "/trading/invoices/12?tab=pagos", last_page_title: "Factura 0012")
    expect(session.last_seen_at).to be_within(5.seconds).of(Time.current)
  end

  it "keeps only paths of this site, and cuts long ones" do
    subscribe
    perform :visit, path: "https://example.com/x", title: ""
    expect(session.reload).to have_attributes(last_path: nil, last_page_title: nil)

    perform :visit, path: "/#{"a" * 400}", title: "x" * 200
    expect(session.reload.last_path.length).to eq(Session::PATH_LENGTH)
    expect(session.last_page_title.length).to eq(Session::TITLE_LENGTH)
  end
end
