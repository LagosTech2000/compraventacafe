import { Controller } from "@hotwired/stimulus"

// The farm field of a purchase: only the farms of the producer picked
// ("record-picker:picked"). Changing producer empties it unless the farm
// belongs to the new one. A farm created in the modal from here
// ("farm:created", for this producer) is added and selected, and so are the
// farms of a producer registered there ("producer:created"); a producer
// completed there ("producer:updated") brings its farms, new ones included.
// "Nueva finca" opens the farm form already set to this producer.
export default class extends Controller {
  static targets = ["select", "hint", "newLink"]
  static values = { farms: Object, producer: String }

  connect() {
    this.blank = this.selectTarget.options[0]?.text || ""
  }

  show({ detail: { id } }) {
    this.producerValue = id || ""
    const farms = this.farmsValue[this.producerValue] || []
    const chosen = this.selectTarget.value
    this.selectTarget.replaceChildren(new Option(this.blank, ""), ...farms.map(([farmId, name]) => new Option(name, farmId)))
    if (farms.some(([farmId]) => String(farmId) === chosen)) this.selectTarget.value = chosen
    this.toggleForProducer()
  }

  // A producer registered in the modal: its farms, before the picker selects it.
  addProducer({ detail: { id, farms } }) {
    this.farmsValue = { ...this.farmsValue, [id]: farms || [] }
  }

  // A producer edited in the modal: its farms now. The list changes only if
  // it is the producer picked, and keeps the farm chosen.
  updateProducer({ detail: { id, farms } }) {
    if (!farms) return
    this.addProducer({ detail: { id, farms } })
    if (String(id) === String(this.producerValue)) this.show({ detail: { id: String(id) } })
  }

  add({ detail: { id, name, producer_id: producerId } }) {
    if (String(producerId) !== String(this.producerValue)) return
    const farms = this.farmsValue
    farms[this.producerValue] = [ ...(farms[this.producerValue] || []), [ id, name ] ]
    this.farmsValue = farms
    this.selectTarget.append(new Option(name, id))
    this.selectTarget.value = String(id)
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
}
