import { Controller } from "@hotwired/stimulus"

// Payment when invoicing: "pending" needs nothing else; "paid" and
// "partial" need the payment method and date, and "partial" the amount
// paid now. Fields that do not apply are hidden, disabled (not sent) and
// not required.
export default class extends Controller {
  static targets = ["status", "paidField", "partialField"]

  connect() {
    this.update()
  }

  update() {
    const status = this.statusTarget.value
    this.paidFieldTargets.forEach((field) => this.toggle(field, status !== "pending"))
    this.partialFieldTargets.forEach((field) => this.toggle(field, status === "partial"))
  }

  toggle(field, visible) {
    field.hidden = !visible
    field.querySelectorAll("input, select").forEach((input) => {
      input.disabled = !visible
      input.required = visible
    })
  }
}
