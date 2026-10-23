import { Controller } from "@hotwired/stimulus"

// The farm field of a purchase: only the farms of the producer picked
// ("record-picker:picked", whose record brings them: [id, name, missing]).
// Changing producer empties it unless the farm belongs to the new one. A
// farm created in the modal from here ("farm:created", for this producer) is
// added and selected; a producer completed there ("producer:updated") brings
// its farms, new ones included. "Nueva finca" opens the farm form already set
// to this producer. Each option keeps what its farm misses (data-missing),
// for farm_gaps_controller.js, told by "producer-farms:changed".
export default class extends Controller {
  static targets = ["select", "hint", "newLink"]
  static values = { farms: Object, producer: String }

  connect() {
    this.blank = this.selectTarget.options[0]?.text || ""
  }

  show({ detail: { id, record } }) {
    this.producerValue = id || ""
    if (record?.farms) this.farmsValue = { ...this.farmsValue, [this.producerValue]: record.farms }
    const farms = this.farmsValue[this.producerValue] || []
    const chosen = this.selectTarget.value
    this.selectTarget.replaceChildren(new Option(this.blank, ""), ...farms.map((farm) => this.option(farm)))
    if (farms.some(([farmId]) => String(farmId) === chosen)) this.selectTarget.value = chosen
    this.toggleForProducer()
    this.changed()
  }

  // A producer edited in the modal: its farms now. The list changes only if
  // it is the producer picked, and keeps the farm chosen.
  updateProducer({ detail: { id, farms } }) {
    if (!farms) return
    this.farmsValue = { ...this.farmsValue, [id]: farms }
    if (String(id) === String(this.producerValue)) this.show({ detail: { id: String(id) } })
  }

  add({ detail: { id, name, producer_id: producerId, missing } }) {
    if (String(producerId) !== String(this.producerValue)) return
    const farms = this.farmsValue
    farms[this.producerValue] = [ ...(farms[this.producerValue] || []), [ id, name, missing || [] ] ]
    this.farmsValue = farms
    this.selectTarget.append(this.option([ id, name, missing || [] ]))
    this.selectTarget.value = String(id)
    this.changed()
  }

  // A farm completed in the modal: what it misses now.
  updateFarm({ detail: { id, name, missing } }) {
    const farms = this.farmsValue
    for (const list of Object.values(farms)) {
      list.forEach((farm, index) => { if (String(farm[0]) === String(id)) list[index] = [ farm[0], name, missing || [] ] })
    }
    this.farmsValue = farms
    const option = Array.from(this.selectTarget.options).find((candidate) => candidate.value === String(id))
    if (!option) return
    option.text = name
    option.dataset.missing = JSON.stringify(missing || [])
    this.changed()
  }

  toggleForProducer() {
    const picked = this.producerValue !== ""
    if (this.hasHintTarget) this.hintTarget.hidden = picked
    if (this.hasNewLinkTarget) {
      this.newLinkTarget.hidden = !picked
      const url = new URL(this.newLinkTarget.dataset.baseHref, window.location.origin)
      url.searchParams.set("producer_id", this.producerValue)
      this.newLinkTarget.href = url.pathname + url.search
    }
  }

  option([ id, name, missing ]) {
    const option = new Option(name, id)
    option.dataset.missing = JSON.stringify(missing || [])
    return option
  }

  changed() {
    this.dispatch("changed")
  }
}
