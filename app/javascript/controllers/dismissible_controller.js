import { Controller } from "@hotwired/stimulus"

// Lets the user close a notice or alert.
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
