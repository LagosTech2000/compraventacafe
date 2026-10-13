import { Controller } from "@hotwired/stimulus"

// Under the producer of a purchase: which of that producer's details are
// still empty (Producer#missing_fields), with a link to complete them in a
// modal. Follows the producer picked ("record-picker:picked"); a producer
// registered or completed in the modal ("producer:created",
// "producer:updated") brings its list along.
export default class extends Controller {
  static targets = ["notice", "text", "link"]
  static values = { missing: Object, message: String, editUrl: String, producer: String }

  connect() {
    this.render()
  }

  show({ detail: { id } }) {
    this.producerValue = id || ""
    this.render()
  }

  // Before the picker selects a producer registered in the modal.
  addProducer({ detail: { id, missing } }) {
    this.missingValue = { ...this.missingValue, [id]: missing || [] }
  }

  updateProducer({ detail: { id, missing } }) {
    this.addProducer({ detail: { id, missing } })
    this.render()
  }

  render() {
    const missing = this.missingValue[this.producerValue] || []
    this.noticeTarget.hidden = missing.length === 0
    if (missing.length === 0) return

    this.textTarget.textContent = this.messageValue.replace("%{fields}", missing.join(", "))
    if (this.hasLinkTarget) this.linkTarget.href = this.editUrlValue.replace("__id__", this.producerValue)
  }
}
