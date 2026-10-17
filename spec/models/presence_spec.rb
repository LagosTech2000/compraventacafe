require "rails_helper"

# Who is online (Presence): a user counts while any tab is connected, the
# user with id 1 never shows, and the home page panel is told each change.
RSpec.describe Presence do
  let(:ana) { create(:user, name: "Ana Zelaya") }
  let(:beto) { create(:user, name: "Beto Mejía") }

  it "never shows the user with id 1, who is also the only one to see pages" do
    expect(Presence::HIDDEN_USER_IDS).to eq([ 1 ])
    expect(Presence::WATCHER_IDS).to eq([ 1 ])
  end

  describe "pages, for the watchers" do
    it "gives each user's most recently active session" do
      ana.sessions.create!(last_seen_at: 10.minutes.ago, last_path: "/loans")
      phone = ana.sessions.create!(last_seen_at: 1.minute.ago, last_path: "/trading/purchases")
      beto.sessions.create!(last_seen_at: 2.minutes.ago, last_path: "/farms")
      described_class.join(ana)
      described_class.join(beto)

      pages = described_class.panel_locals(pages: true)[:pages]
      expect(pages[ana.id]).to eq(phone)
      expect(pages[beto.id].last_path).to eq("/farms")
    end

    it "is a watcher only while active" do
      stub_const("Presence::WATCHER_IDS", [ ana.id ])
      expect(described_class.watcher?(ana)).to be(true)
      expect(described_class.watcher?(beto)).to be(false)
      expect(described_class.watcher?(nil)).to be_falsey
      ana.update!(active: false)
      expect(described_class.watcher?(ana)).to be(false)
    end

    it "tells only the watchers' stream that someone changed page, never for the hidden user" do
      stub_const("Presence::HIDDEN_USER_IDS", [ beto.id ])
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)

      described_class.page_changed(ana)
      described_class.page_changed(beto)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).once
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(Presence::WATCH_STREAM, hash_including(target: "active-users"))
    end
  end

  it "shows a user while any of their tabs is connected, by name" do
    described_class.join(beto)
    described_class.join(ana)
    described_class.join(ana)
    expect(described_class.visible_users).to eq([ ana, beto ])

    described_class.leave(ana)
    expect(described_class.visible_users).to eq([ ana, beto ])
    described_class.leave(ana)
    expect(described_class.visible_users).to eq([ beto ])
  end

  it "hides the hidden user and inactive users" do
    stub_const("Presence::HIDDEN_USER_IDS", [ ana.id ])
    described_class.join(ana)
    described_class.join(beto)
    beto.update!(active: false)

    expect(described_class.visible_users).to be_empty
  end

  it "replaces the panel when someone comes or goes, not on every tab" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)

    described_class.join(ana)
    described_class.join(ana)
    described_class.leave(ana)
    described_class.leave(ana)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
      .with(:presence, target: "active-users", partial: "dashboard/active_users", locals: { users: [ ana ], recent: [], pages: nil, visits: {}, changes: {} }, attributes: { method: :morph }).once
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
      .with(Presence::WATCH_STREAM, target: "active-users", partial: "dashboard/active_users", locals: { users: [ ana ], recent: [], pages: {}, visits: {}, changes: {} }, attributes: { method: :morph }).once
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
      .with(:presence, target: "active-users", partial: "dashboard/active_users", locals: { users: [], recent: [], pages: nil, visits: {}, changes: {} }, attributes: { method: :morph }).once
  end

  describe "recent activity" do
    def session_for(user, seen:) = user.sessions.create!(last_seen_at: seen)

    it "lists who is not connected but did something in the last hour, latest first, with the time" do
      session_for(ana, seen: 50.minutes.ago)
      session_for(beto, seen: 70.minutes.ago)
      session_for(beto, seen: 5.minutes.ago) # another device: the latest counts
      carla = create(:user, name: "Carla Ríos")
      session_for(carla, seen: 61.minutes.ago)

      recent = described_class.recent_users.to_a
      expect(recent).to eq([ beto, ana ])
      expect(recent.first.last_seen_at).to be_within(1.second).of(5.minutes.ago)
    end

    it "leaves out who is connected now, the hidden user, inactive users and signed-out sessions" do
      dora = create(:user, name: "Dora Paz")
      eva = create(:user, name: "Eva Cruz")
      [ ana, beto, dora, eva ].each { session_for(it, seen: 1.minute.ago) }
      described_class.join(ana)
      stub_const("Presence::HIDDEN_USER_IDS", [ beto.id ])
      dora.update!(active: false)
      eva.sessions.destroy_all

      expect(described_class.recent_users).to be_empty
    end

    it "moves a user to recent when their last tab closes" do
      session_for(ana, seen: 1.minute.ago)
      described_class.join(ana)
      expect(described_class.panel_locals).to eq(users: [ ana ], recent: [], pages: nil, visits: {}, changes: {})

      described_class.leave(ana)
      expect(described_class.panel_locals).to eq(users: [], recent: [ ana ], pages: nil, visits: {}, changes: {})
    end
  end

  describe "the watchers' cards" do
    it "brings the latest pages and changes of each user, up to CARD_ITEMS" do
      stub_const("Presence::CARD_ITEMS", 2)
      described_class.join(ana)
      described_class.join(beto)
      3.times { |i| PageVisit.record!(user: ana, path: "/ana/#{i}", title: nil, at: i.minutes.ago) }
      PageVisit.record!(user: beto, path: "/beto", title: nil)
      3.times do |i|
        AuditEvent.create!(user: ana, user_email: "ana@example.com", action: "sign_in", auditable_label: "ana #{i}", created_at: i.minutes.ago)
      end

      locals = described_class.panel_locals(pages: true)
      expect(locals[:visits][ana.id].map(&:path)).to eq(%w[/ana/0 /ana/1])
      expect(locals[:visits][beto.id].map(&:path)).to eq(%w[/beto])
      expect(locals[:changes][ana.id].map(&:auditable_label)).to eq([ "ana 0", "ana 1" ])
      expect(locals[:changes]).not_to have_key(beto.id)
    end
  end
end
