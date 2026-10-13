import { Controller } from "@hotwired/stimulus"

// The role checkboxes of a person form: at least one must be checked (the
// browser says so in Spanish before sending; the server checks it too), and
// the kind of producer shows only while "Productor" is checked.
export default class extends Controller {
  static targets = ["checkbox", "producer", "kind"]
  static values = { requiredMessage: String }

  connect() {
    this.update()
  }

  update() {
    const none = !this.checkboxTargets.some((checkbox) => checkbox.checked)
    const first = this.checkboxTargets.find((checkbox) => !checkbox.disabled)
    first?.setCustomValidity(none ? this.requiredMessageValue : "")

    if (this.hasKindTarget && this.hasProducerTarget) this.kindTarget.hidden = !this.producerTarget.checked
  }
}
