# What the fingerprint reader of this PC says, for the browsers linked to its
# station (Fernando, 2026-11-14; fingerprint.js): who put a finger, how an
# enrollment goes and whether the reader is connected. Only ids travel: each
# page asks the server what to show, with its user's permissions.
class FingerprintChannel < ApplicationCable::Channel
  def subscribed
    station = current_user && linked_station_id && FingerprintStation.active.find_by(id: linked_station_id)
    return reject unless station

    stream_for station
  end
end
