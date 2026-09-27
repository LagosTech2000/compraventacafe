import { Controller } from "@hotwired/stimulus"

// Searchable producer picker: a text input backed by a <datalist> (works on
// phones too). Choosing an entry fills the hidden producer_id and, when the
// zone is still empty, the producer's usual zone.
export default class extends Controller {
  static targets = ["search", "options", "id", "zone"]
  static values = { producers: Object, missingMessage: String }

  connect() {
    this.byLabel = new Map()
    for (const [id, { label, zone_id }] of Object.entries(this.producersValue)) {
      this.byLabel.set(label, { id, zoneId: zone_id })
      this.optionsTarget.append(new Option(label))
    }
  }

  pick() {
    const match = this.byLabel.get(this.searchTarget.value)
    this.idTarget.value = match ? match.id : ""
    this.searchTarget.setCustomValidity(match || this.searchTarget.value === "" ? "" : this.missingMessageValue)

    if (match && match.zoneId && this.hasZoneTarget && this.zoneTarget.value === "") {
      this.zoneTarget.value = String(match.zoneId)
    }
  }
}
