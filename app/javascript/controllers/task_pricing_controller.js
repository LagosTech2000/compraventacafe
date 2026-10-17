import { Controller } from "@hotwired/stimulus"

// Task form: how the task is paid (PayrollTask::PRICINGS). Shows only the
// fields of the chosen way (elements with data-pricings), disables the rest
// so they are neither checked nor sent, and for quantity × price fills the
// value (read-only) and tells task-split to show each one's part. A
// preview: the server calculates the value again. By manzana, the
// quantity can't pass the farm's extension (data-manzanas).
export default class extends Controller {
  static targets = ["pricing", "quantity", "unitPrice", "amount"]

  connect() {
    this.update()
  }

  update() {
    const pricing = this.pricingTarget.value
    this.element.querySelectorAll("[data-pricings]").forEach((element) => {
      const shown = element.dataset.pricings.split(" ").includes(pricing)
      element.hidden = !shown
      if (element.matches("span")) return
      element.querySelectorAll("input, select").forEach((field) => { field.disabled = !shown && !this.isAlwaysOn(field) })
    })

    const manzanas = this.quantityTarget.dataset.manzanas
    if (pricing === "per_manzana" && manzanas) this.quantityTarget.max = manzanas
    else this.quantityTarget.removeAttribute("max")

    const fixed = pricing === "fixed"
    this.amountTarget.readOnly = !fixed
    if (!fixed) {
      const quantity = parseFloat(this.quantityTarget.value)
      const price = parseFloat(this.unitPriceTarget.value)
      this.amountTarget.value = quantity > 0 && price > 0 ? (Math.round(quantity * price * 100) / 100).toFixed(2) : ""
    }
    this.amountTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  // The value box sits outside the pricing groups: never disabled.
  isAlwaysOn(field) {
    return field === this.amountTarget
  }
}
