import { Controller } from "@hotwired/stimulus"

// Searchable picker (producers in a purchase, people in a loan): a text
// input backed by a <datalist> (works on phones too). Choosing an entry
// fills the hidden id and, with a zone field, switches it to the record's
// zone (a zone filled for the previous record is cleared if the new one has
// none; one picked by hand stays), and announces it ("record-picker:picked",
// e.g. for the producer's farms). A record created in the modal (an event
// such as "producer:created", wired in the view to #add) is added and selected;
// one edited there (#replace) changes its label and zone.
export default class extends Controller {
  static targets = ["search", "options", "id", "zone"]
  static values = { records: Object, missingMessage: String }

  connect() {
    this.byLabel = new Map()
    for (const [id, { label, zone_id }] of Object.entries(this.recordsValue)) this.register(id, label, zone_id)
    this.pickedId = this.idTarget.value
    this.autoZone = this.hasZoneTarget ? this.zoneTarget.value : ""
  }

  pick() {
    const match = this.byLabel.get(this.searchTarget.value)
    this.idTarget.value = match ? match.id : ""
    this.searchTarget.setCustomValidity(match || this.searchTarget.value === "" ? "" : this.missingMessageValue)

    if (match && match.id !== this.pickedId) this.fillZone(match.zoneId)
    if ((match?.id || "") !== (this.pickedId || "")) this.dispatch("picked", { detail: { id: match?.id || "" } })
    this.pickedId = match ? match.id : ""
  }

  fillZone(zoneId) {
    if (!this.hasZoneTarget) return

    const previousAutoZone = this.autoZone
    this.autoZone = zoneId ? String(zoneId) : ""
    if (zoneId) {
      this.zoneTarget.value = this.autoZone
    } else if (this.zoneTarget.value === previousAutoZone) {
      this.zoneTarget.value = ""
    }
  }

  add({ detail: { id, label, zone_id } }) {
    this.register(String(id), label, zone_id)
    this.searchTarget.value = label
    this.pick()
  }

  // A record edited in the modal ("producer:updated", wired in the view):
  // its new label and zone; still picked if it was.
  replace({ detail: { id, label, zone_id } }) {
    id = String(id)
    for (const [oldLabel, record] of this.byLabel) {
      if (record.id !== id) continue
      this.byLabel.delete(oldLabel)
      const option = Array.from(this.optionsTarget.options).find((candidate) => candidate.value === oldLabel)
      option?.remove()
    }
    this.register(id, label, zone_id)
    if (this.pickedId !== id) return

    this.searchTarget.value = label
    this.fillZone(zone_id)
  }

  register(id, label, zoneId) {
    if (this.byLabel.has(label)) return
    this.byLabel.set(label, { id, zoneId })
    this.optionsTarget.append(new Option(label))
  }
}
