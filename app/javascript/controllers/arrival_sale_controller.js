import { Controller } from "@hotwired/stimulus"

// «Liquidar salida» (Fernando, 2026-11-18): the sale's total on the buyer's
// net as it is typed (weighing_calculator's net), by the quintal (its
// pounds) or by the pound, like Sale.amount_for. Only a preview: the
// server computes it.
export default class extends Controller {
  static targets = ["unit", "quintalField", "quintalPounds", "price", "total"]

  connect() {
    this.form = this.element.closest("form")
    this.onInput = () => this.update()
    this.form?.addEventListener("input", this.onInput)
    this.money = new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  disconnect() {
    this.form?.removeEventListener("input", this.onInput)
  }

  update() {
    const unit = this.unitTargets.find((radio) => radio.checked)?.value || "quintal"
    this.quintalFieldTarget.hidden = unit !== "quintal"
    const netText = this.form?.querySelector("[data-weighing-calculator-target='net']")?.textContent || ""
    const net = parseFloat(netText.replace(/,/g, ""))
    const price = parseFloat(this.priceTarget.value)
    const pounds = parseFloat(this.quintalPoundsTarget.value)
    if (!(net > 0) || !(price > 0) || (unit === "quintal" && !(pounds > 0))) {
      this.totalTarget.textContent = "—"
      return
    }
    const total = unit === "quintal" ? (net / pounds) * price : net * price
    this.totalTarget.textContent = `L ${this.money.format(Math.round(total * 100) / 100)}`
  }
}
