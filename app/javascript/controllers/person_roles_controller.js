import { Controller } from "@hotwired/stimulus"

// The role checkboxes of a person form: at least one must be checked (the
// browser says so in Spanish before sending; the server checks it too). The
// kind of producer shows only while "Productor" is checked, and a new
// hauler's commission percent and can price only while "Carrero" is
// (disabled while hidden, so they are neither required nor sent).
export default class extends Controller {
  static targets = ["checkbox", "producer", "kind", "hauler", "haulerTerms"]
  static values = { requiredMessage: String }

  connect() {
    this.update()
  }

  update() {
    const none = !this.checkboxTargets.some((checkbox) => checkbox.checked)
    const first = this.checkboxTargets.find((checkbox) => !checkbox.disabled)
    first?.setCustomValidity(none ? this.requiredMessageValue : "")

    if (this.hasKindTarget && this.hasProducerTarget) this.kindTarget.hidden = !this.producerTarget.checked
    if (this.hasHaulerTermsTarget && this.hasHaulerTarget) {
      const shown = this.haulerTarget.checked
      this.haulerTermsTarget.hidden = !shown
      this.haulerTermsTarget.querySelectorAll("input").forEach((input) => { input.disabled = !shown })
    }
  }
}
