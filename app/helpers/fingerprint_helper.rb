# The fingerprint reader of this PC (Fernando, 2026-11-14): the station this
# browser is linked to (its signed cookie), the texts fingerprint.js shows,
# and a page's own action for a person identified by a finger.
module FingerprintHelper
  def linked_fingerprint_station
    return @linked_fingerprint_station if defined?(@linked_fingerprint_station)

    id = authenticated? && cookies.signed[FingerprintStation::COOKIE]
    @linked_fingerprint_station = id ? FingerprintStation.active.find_by(id:) : nil
  end

  def fingerprint_texts
    t("fingerprints.client").merge(dismiss: t("shared.flash.dismiss")).to_json
  end

  # The address a page goes to when a finger is identified there, with
  # __person_id__, __producer_id__ or __hauler_id__ in it.
  #
  #   <div <%= tag.attributes(data: fingerprint_visit(trading_producer_path("__producer_id__"))) %>>
  def fingerprint_visit(url) = { fingerprint_visit: url }
end
