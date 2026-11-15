# The channel of a fingerprint bridge (tools/fingerprint_bridge, Fernando,
# 2026-11-14): only a paired station's bridge subscribes. It hears "enroll"
# (an administrator asked to register a finger at this PC) and
# "templates_changed" (load the templates again); it tells who put a finger,
# how an enrollment goes and whether the reader is connected
# (FingerprintEvents passes it on to the browsers of that PC).
class FingerprintBridgeChannel < ApplicationCable::Channel
  def subscribed
    return reject unless fingerprint_station

    fingerprint_station.seen!
    stream_for fingerprint_station
    stream_from Fingerprint::BRIDGES_STREAM
    events.bridge(connected: true)
  end

  def unsubscribed
    events.bridge(connected: false) if fingerprint_station
  end

  # { "fid" => the fingerprint's id or nil, "score" }
  def identified(data) = events.identified(data["fid"], data["score"])

  # { "connected" => true/false }
  def reader(data) = events.reader(connected: data["connected"] == true)

  # { "request_id", "step" } (1 to 3)
  def enroll_progress(data) = events.enroll_progress(data["request_id"], data["step"])

  # { "request_id", "template" (base64), "duplicate_fid" }
  def enrolled(data) = events.enrolled(data["request_id"], template: data["template"], duplicate_fid: data["duplicate_fid"])

  # { "request_id", "reason" }
  def enroll_failed(data) = events.enroll_failed(data["request_id"], data["reason"])

  private
    def events = FingerprintEvents.new(fingerprint_station)
end
