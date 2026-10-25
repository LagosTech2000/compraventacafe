import { Controller } from "@hotwired/stimulus"

// The account form's bank: only for a bank account, picked from Honduras'
// main banks, or typed by hand with «Otro banco». Fields that do not apply
// are hidden and disabled (not sent).
export default class extends Controller {
  static targets = ["kind", "bankFields", "bank", "otherField"]

  connect() {
    this.update()
  }

  update() {
    const bank = this.kindTarget.value === "bank"
    this.toggle(this.bankFieldsTarget, bank)
    this.toggle(this.otherFieldTarget, bank && this.bankTarget.value === "other")
  }

  toggle(element, visible) {
    element.hidden = !visible
    element.querySelectorAll("input, select").forEach((input) => {
      input.disabled = !visible
      if (input.dataset.requiredWhenShown) input.required = visible
    })
  }
}
