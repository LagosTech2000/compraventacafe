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
      .with(:presence, target: "active-users", partial: "dashboard/active_users", locals: { users: [ ana ] }).once
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
      .with(:presence, target: "active-users", partial: "dashboard/active_users", locals: { users: [] }).once
  end
end
