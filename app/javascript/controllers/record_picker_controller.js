import { Controller } from "@hotwired/stimulus"

// Searchable picker (producers in a purchase, people in a loan): a text
// input backed by a <datalist> (works on phones too). Choosing an entry
// fills the hidden id and, when the record has a zone and the zone field is
// still empty, that zone. A record created in the modal (an event such as
// "producer:created", wired in the view to #add) is added and selected.
export default class extends Controller {
  static targets = ["search", "options", "id", "zone"]
  static values = { records: Object, missingMessage: String }

  connect() {
    this.byLabel = new Map()
    for (const [id, { label, zone_id }] of Object.entries(this.recordsValue)) this.register(id, label, zone_id)
  }

  pick() {
    const match = this.byLabel.get(this.searchTarget.value)
    this.idTarget.value = match ? match.id : ""
    this.searchTarget.setCustomValidity(match || this.searchTarget.value === "" ? "" : this.missingMessageValue)

    if (match && match.zoneId && this.hasZoneTarget && this.zoneTarget.value === "") {
      this.zoneTarget.value = String(match.zoneId)
    }
  }

  add({ detail: { id, label, zone_id } }) {
    this.register(String(id), label, zone_id)
    this.searchTarget.value = label
    this.pick()
  }

  register(id, label, zoneId) {
    if (this.byLabel.has(label)) return
    this.byLabel.set(label, { id, zoneId })
    this.optionsTarget.append(new Option(label))
  }
}
