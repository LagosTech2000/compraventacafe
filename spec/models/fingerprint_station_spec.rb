require "rails_helper"

# A PC with a fingerprint reader (Fernando, 2026-11-14): its bridge pairs once
# with a code that expires, and then uses a token; only digests are kept.
RSpec.describe FingerprintStation do
  include ActiveSupport::Testing::TimeHelpers

  let(:station) { create(:fingerprint_station) }

  it "pairs once with its code, within its minutes, and gives a token" do
    station.start_pairing!
    code = station.pairing_code
    expect(station.reload.pairing_code_digest).not_to eq(code)

    paired, token = described_class.pair!("#{code[0, 3]} #{code[3, 3]}")
    expect(paired).to eq(station)
    expect(described_class.authenticate(token)).to eq(station)
    expect(station.reload).to have_attributes(pairing_code_digest: nil, token_digest: described_class.digest(token))
    expect(described_class.pair!(code)).to be_nil
  end

  it "does not pair with an expired code, a wrong one or a deactivated station" do
    station.start_pairing!
    code = station.pairing_code
    travel_to (described_class::PAIRING_MINUTES + 1).minutes.from_now do
      expect(described_class.pair!(code)).to be_nil
    end
    expect(described_class.pair!("12345")).to be_nil

    station.start_pairing!
    code = station.pairing_code
    station.deactivate!
    expect(described_class.pair!(code)).to be_nil
  end

  it "stops its token when deactivated" do
    station.start_pairing!
    _, token = described_class.pair!(station.pairing_code)
    station.reload.deactivate!
    expect(described_class.authenticate(token)).to be_nil
    expect(described_class.authenticate("")).to be_nil
  end

  it "keeps whether its bridge and reader are connected" do
    described_class.reset_states!
    expect(station.state).to eq(bridge: false, reader: false)
    described_class.change_state(station.id, bridge: true, reader: true)
    expect(station.state).to eq(bridge: true, reader: true)
  end
end
