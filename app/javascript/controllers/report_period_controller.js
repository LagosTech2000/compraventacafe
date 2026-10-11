import { Controller } from "@hotwired/stimulus"

// Report period: the date fields only count for "Personalizado". Picking a
// listed period hides and clears them; typing a date picks "Personalizado".
export default class extends Controller {
  static targets = ["select", "dates"]

  connect() {
    this.inputs.forEach((input) => input.addEventListener("change", this.typed))
    this.toggle()
  }

  disconnect() {
    this.inputs.forEach((input) => input.removeEventListener("change", this.typed))
  }

  change() {
    if (this.selectTarget.value !== "custom") this.inputs.forEach((input) => { input.value = "" })
    this.toggle()
  }

  typed = () => {
    if (this.inputs.some((input) => input.value)) this.selectTarget.value = "custom"
  }

  toggle() {
    const custom = this.selectTarget.value === "custom"
    this.datesTarget.querySelectorAll(":scope > div").forEach((field) => { field.hidden = !custom })
    this.inputs.forEach((input) => { input.disabled = !custom })
  }

  get inputs() {
    return [...this.datesTarget.querySelectorAll("input")]
  }
}
