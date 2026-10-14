require "rails_helper"

# Who is online (Presence): a user counts while any tab is connected, the
# user with id 1 never shows, and the home page panel is told each change.
RSpec.describe Presence do
  let(:ana) { create(:user, name: "Ana Zelaya") }
  let(:beto) { create(:user, name: "Beto Mejía") }

  it "never shows the user with id 1" do
    expect(Presence::HIDDEN_USER_IDS).to eq([ 1 ])
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
      .with(:presence, target: "active-users", partial: "dashboard/active_users", locals: { users: [ ana ], recent: [] }).once
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
      .with(:presence, target: "active-users", partial: "dashboard/active_users", locals: { users: [], recent: [] }).once
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
      expect(described_class.panel_locals).to eq(users: [ ana ], recent: [])

      described_class.leave(ana)
      expect(described_class.panel_locals).to eq(users: [], recent: [ ana ])
    end
  end
end
