import { Controller } from "@hotwired/stimulus"

// A field that can be repeated (a producer's farms): "+ Agregar otra"
// adds one more from the <template> and puts the cursor in it.
export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
    this.listTarget.lastElementChild?.focus()
  }
}
