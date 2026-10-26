import { Controller } from "@hotwired/stimulus"

// A processing cost as it is typed (the server repeats it on save): an
// agreed total, or a price per pound or per quintal on one of the process's
// weights (what went in or came out, gross or net). Shows only the fields
// of the way it is charged, and the amount it comes to.
export default class extends Controller {
  static targets = ["pricing", "unitFields", "quintalField", "side", "kind", "quintals", "unitPrice", "amount", "amountField", "base", "result"]
  static values = { bases: Object }

  connect() {
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    const pricing = this.checked(this.pricingTargets) || "total"
    const total = pricing === "total"
    this.toggle(this.unitFieldsTarget, !total)
    this.toggle(this.quintalFieldTarget, pricing === "per_quintal")
    this.toggle(this.amountFieldTarget, total)
    if (total) {
      this.baseTarget.textContent = ""
      const amount = parseFloat(this.amountTarget.value)
      this.resultTarget.textContent = amount > 0 ? `L ${this.money.format(amount)}` : "—"
      return
    }

    const pounds = parseFloat(this.basesValue[this.checked(this.sideTargets)]?.[this.checked(this.kindTargets)])
    const price = parseFloat(this.unitPriceTarget.value)
    const quantity = pricing === "per_pound" ? pounds : pounds / parseInt(this.quintalsTarget.value, 10)
    this.baseTarget.textContent = pounds > 0 ? `${this.money.format(pounds)} lb` : "—"
    this.resultTarget.textContent = quantity > 0 && price > 0 ? `L ${this.money.format(Math.round(quantity * price * 100) / 100)}` : "—"
  }

  checked(radios) {
    return radios.find((radio) => radio.checked)?.value
  }

  // Hidden fields are not sent: the server only gets the way it was charged.
  toggle(element, shown) {
    element.hidden = !shown
    element.querySelectorAll("input, select").forEach((input) => { input.disabled = !shown || input.dataset.alwaysDisabled === "true" })
  }
}
