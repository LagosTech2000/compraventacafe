import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a field changes (e.g. picking a date), so no
// separate button is needed. Pressing Enter still works without JavaScript.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
