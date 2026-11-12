import { Controller } from "@hotwired/stimulus"

// «Sin báscula local» on a shipment (administrators, Fernando, 2026-11-12):
// checked, the local scale's fieldset hides and is disabled as a whole (its
// fields are neither sent nor required); unchecked, each field is again as
// the weighing calculator left it.
export default class extends Controller {
  static targets = ["toggle", "fields"]

  connect() {
    this.update()
  }

  update() {
    const skip = this.toggleTarget.checked
    this.fieldsTarget.hidden = skip
    this.fieldsTarget.disabled = skip
  }
}
