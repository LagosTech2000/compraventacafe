require "rails_helper"

# The bridge of a PC and the browsers linked to it (Fernando, 2026-11-14).
RSpec.describe "Fingerprint channels", type: :channel do
  let(:admin) { create(:user, :admin) }
  let(:station) { create(:fingerprint_station, :paired) }

  before do
    FingerprintStation.reset_states!
    FingerprintEnrollment.clear!
  end

  describe ApplicationCable::Connection, type: :channel do
    it "lets a bridge in with its station's token, and not with another" do
      connect "/cable", headers: { "Authorization" => "Bearer token-#{station.name.parameterize}" }
      expect(connection.fingerprint_station).to eq(station)
      expect(connection.current_user).to be_nil

      expect { connect "/cable", headers: { "Authorization" => "Bearer otro" } }.to have_rejected_connection
    end

    it "knows the station a signed-in browser is linked to" do
      session = admin.sessions.create!
      cookies.signed[:session_id] = session.id
      cookies.signed[FingerprintStation::COOKIE] = station.id
      connect "/cable"
      expect(connection.linked_station_id).to eq(station.id)
    end
  end

  describe FingerprintBridgeChannel, type: :channel do
    it "takes only a station's bridge, and says it is connected to the browsers" do
      stub_connection fingerprint_station: nil, current_user: admin
      subscribe
      expect(subscription).to be_rejected

      stub_connection fingerprint_station: station
      expect { subscribe }.to have_broadcasted_to(station).from_channel(FingerprintChannel).with(type: "state", bridge: true, reader: false)
      expect(subscription).to have_stream_for(station)
      expect(subscription).to have_stream_from(Fingerprint::BRIDGES_STREAM)

      expect { perform :reader, connected: true }.to have_broadcasted_to(station).from_channel(FingerprintChannel).with(type: "state", bridge: true, reader: true)
      expect { unsubscribe }.to have_broadcasted_to(station).from_channel(FingerprintChannel).with(type: "state", bridge: false, reader: false)
    end

    it "passes on who put a finger, or that nobody is known" do
      fingerprint = create(:fingerprint)
      stub_connection fingerprint_station: station
      subscribe

      expect { perform :identified, fid: fingerprint.id, score: 87 }
        .to have_broadcasted_to(station).from_channel(FingerprintChannel).with(type: "identified", person_id: fingerprint.person_id, score: 87)
      expect { perform :identified, fid: nil, score: 0 }.to have_broadcasted_to(station).from_channel(FingerprintChannel).with(type: "unknown")
    end

    it "registers a finger asked at its PC, as the administrator who asked" do
      person = create(:person)
      Current.session = admin.sessions.create!
      request_id = FingerprintEnrollment.start!(station:, person:, finger: "left_thumb", user: admin)
      Current.reset
      stub_connection fingerprint_station: station
      subscribe

      expect { perform :enroll_progress, request_id:, step: 2 }
        .to have_broadcasted_to(station).from_channel(FingerprintChannel).with(type: "enroll_progress", request_id:, step: 2)

      template = Base64.strict_encode64(Random.bytes(500))
      expect { perform :enrolled, request_id:, template:, duplicate_fid: nil }
        .to have_broadcasted_to(station).from_channel(FingerprintChannel).with(type: "enrolled", request_id:, person_id: person.id)
      expect(person.fingerprints.sole).to have_attributes(finger: "left_thumb", template:, created_by: admin)
      expect(AuditEvent.where(auditable_type: "Fingerprint").sole.user).to eq(admin)

      # Once only.
      expect { perform :enrolled, request_id:, template:, duplicate_fid: nil }.not_to have_broadcasted_to(station).from_channel(FingerprintChannel)
    end

    it "does not register a finger that is already someone else's, nor another station's request" do
      other = create(:fingerprint)
      person = create(:person)
      request_id = FingerprintEnrollment.start!(station:, person:, finger: "right_index", user: admin)
      stub_connection fingerprint_station: station
      subscribe

      expect { perform :enrolled, request_id:, template: Base64.strict_encode64("x" * 100), duplicate_fid: other.id }
        .to have_broadcasted_to(station).from_channel(FingerprintChannel)
        .with(type: "enroll_failed", request_id:, message: "Esa huella ya está registrada para #{other.person.full_name} (Índice derecho). Si es la misma persona, fusiona las dos personas.")
      expect(person.fingerprints).to be_empty

      another = create(:fingerprint_station, :paired)
      foreign = FingerprintEnrollment.start!(station: another, person:, finger: "right_index", user: admin)
      expect { perform :enroll_failed, request_id: foreign, reason: "mismatch" }.not_to have_broadcasted_to(station).from_channel(FingerprintChannel)
      expect { perform :enroll_failed, request_id: foreign, reason: "mismatch" }.not_to have_broadcasted_to(another).from_channel(FingerprintChannel)
    end

    it "says why the reader could not register" do
      request_id = FingerprintEnrollment.start!(station:, person: create(:person), finger: "right_index", user: admin)
      stub_connection fingerprint_station: station
      subscribe

      expect { perform :enroll_failed, request_id:, reason: "mismatch" }
        .to have_broadcasted_to(station).from_channel(FingerprintChannel)
        .with(type: "enroll_failed", request_id:, message: "No fue el mismo dedo las 3 veces. Inténtalo otra vez.")
    end
  end

  describe FingerprintChannel, type: :channel do
    it "takes a signed-in browser linked to an active station" do
      stub_connection current_user: admin, linked_station_id: station.id
      subscribe
      expect(subscription).to have_stream_for(station)

      stub_connection current_user: admin, linked_station_id: nil
      subscribe
      expect(subscription).to be_rejected

      station.deactivate!
      stub_connection current_user: admin, linked_station_id: station.id
      subscribe
      expect(subscription).to be_rejected
    end
  end
end
