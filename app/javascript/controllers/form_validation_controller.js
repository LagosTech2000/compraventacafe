import { Controller } from "@hotwired/stimulus"

// Replaces the browser's generic validation messages with the Spanish ones
// each field carries (data-missing-message, data-invalid-message), and checks
// confirmation fields (data-must-match="<id>", data-mismatch-message).
export default class extends Controller {
  connect() {
    this.element.addEventListener("invalid", this.explain, true)
    this.element.addEventListener("input", this.revalidate, true)
    this.element.addEventListener("change", this.revalidate, true)
  }

  disconnect() {
    this.element.removeEventListener("invalid", this.explain, true)
    this.element.removeEventListener("input", this.revalidate, true)
    this.element.removeEventListener("change", this.revalidate, true)
  }

  explain = (event) => {
    const field = event.target
    const { validity, dataset } = field
    if (validity.customError) return

    let message = ""
    if (validity.valueMissing) message = dataset.missingMessage
    else if (validity.patternMismatch || validity.typeMismatch || validity.tooShort || validity.tooLong) message = dataset.invalidMessage

    if (message) field.setCustomValidity(message)
  }

  revalidate = (event) => {
    if (typeof event.target.setCustomValidity === "function") event.target.setCustomValidity("")
    this.checkConfirmations()
  }

  checkConfirmations() {
    this.element.querySelectorAll("[data-must-match]").forEach((field) => {
      const original = this.element.querySelector(`#${CSS.escape(field.dataset.mustMatch)}`)
      const mismatch = original && field.value !== "" && field.value !== original.value
      field.setCustomValidity(mismatch ? field.dataset.mismatchMessage : "")
    })
  }
}
