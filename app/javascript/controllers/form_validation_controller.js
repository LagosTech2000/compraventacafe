import { Controller } from "@hotwired/stimulus"

// Replaces the browser's generic validation messages with the Spanish ones
// each field carries in data-missing-message and data-invalid-message.
export default class extends Controller {
  connect() {
    this.element.addEventListener("invalid", this.explain, true)
    this.element.addEventListener("input", this.reset, true)
    this.element.addEventListener("change", this.reset, true)
  }

  disconnect() {
    this.element.removeEventListener("invalid", this.explain, true)
    this.element.removeEventListener("input", this.reset, true)
    this.element.removeEventListener("change", this.reset, true)
  }

  explain = (event) => {
    const field = event.target
    const { validity, dataset } = field
    if (validity.customError) return

    let message = ""
    if (validity.valueMissing) message = dataset.missingMessage
    else if (validity.patternMismatch || validity.typeMismatch || validity.tooLong) message = dataset.invalidMessage

    if (message) field.setCustomValidity(message)
  }

  reset = (event) => {
    if (typeof event.target.setCustomValidity === "function") event.target.setCustomValidity("")
  }
}
