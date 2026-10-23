import { Controller } from "@hotwired/stimulus"

// A <select> that gains and selects an option created in the modal. Listen
// for the record's event, e.g. data-action="zone:created@window->option-picker#add".
// The event detail carries { id, name }, and optionally `data` for the
// option's data attributes (a carrero's percent and can price).
export default class extends Controller {
  static targets = ["select"]

  add({ detail: { id, name, data } }) {
    const value = String(id)
    let option = [...this.selectTarget.options].find((candidate) => candidate.value === value)
    if (!option) {
      option = new Option(name, value)
      this.selectTarget.add(option)
    }
    Object.entries(data || {}).forEach(([key, datum]) => { option.dataset[key] = datum })
    this.selectTarget.value = value
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
