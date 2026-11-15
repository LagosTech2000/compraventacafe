# What a fingerprint bridge reports (FingerprintBridgeChannel), passed on to
# the browsers of its PC (FingerprintChannel) as ids and states only.
class FingerprintEvents
  attr_reader :station

  def initialize(station)
    @station = station
  end

  def bridge(connected:)
    FingerprintStation.change_state(station.id, bridge: connected, **(connected ? {} : { reader: false }))
    announce_state
  end

  def reader(connected:)
    station.seen!
    FingerprintStation.change_state(station.id, reader: connected)
    announce_state
  end

  # A finger put on the reader: the person it is, or nobody.
  def identified(fid, score)
    fingerprint = Fingerprint.find_by(id: fid) if fid.present?
    if fingerprint
      tell(type: "identified", person_id: fingerprint.person_id, score: score.to_i)
    else
      tell(type: "unknown")
    end
  end

  def enroll_progress(request_id, step)
    enrollment = FingerprintEnrollment.find(request_id, station:)
    tell(type: "enroll_progress", request_id:, step: step.to_i.clamp(0, FingerprintEnrollment::CAPTURES)) if enrollment
  end

  def enrolled(request_id, template:, duplicate_fid:)
    enrollment = FingerprintEnrollment.find(request_id, station:)
    return unless enrollment

    fingerprint, error = enrollment.complete!(template:, duplicate_fid:)
    if fingerprint
      tell(type: "enrolled", request_id:, person_id: fingerprint.person_id)
    else
      tell(type: "enroll_failed", request_id:, message: error)
    end
  end

  def enroll_failed(request_id, reason)
    enrollment = FingerprintEnrollment.find(request_id, station:)
    return unless enrollment

    enrollment.forget!
    tell(type: "enroll_failed", request_id:, message: FingerprintEnrollment.failure_message(reason))
  end

  private
    def tell(payload) = FingerprintChannel.broadcast_to(station, payload)

    def announce_state = tell(type: "state", **FingerprintStation.state(station.id))
end
