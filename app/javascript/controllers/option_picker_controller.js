import { Controller } from "@hotwired/stimulus"

// A <select> that gains and selects an option created in the modal. Listen
// for the record's event, e.g. data-action="zone:created@window->option-picker#add".
// The event detail carries { id, name }.
export default class extends Controller {
  static targets = ["select"]

  add({ detail: { id, name } }) {
    const value = String(id)
    if (![...this.selectTarget.options].some((option) => option.value === value)) {
      this.selectTarget.add(new Option(name, value))
    }
    this.selectTarget.value = value
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
