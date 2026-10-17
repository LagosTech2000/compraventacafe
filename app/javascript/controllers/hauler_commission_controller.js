import { Controller } from "@hotwired/stimulus"

// Purchase form: the commission of the carrero chosen (Hauler), as a
// preview. Cans = net pounds ÷ the pounds of a can; commission = cans ×
// can price × percent. Each option of the select carries its hauler's
// percent and can price (for the hauler already on the purchase, the ones
// it kept). The net weight comes from purchase-calculator's "calculated"
// event; the server calculates it again.
export default class extends Controller {
  static targets = ["select", "box", "cans", "terms", "amount"]
  static values = { canPounds: Number, termsLabel: String }

  connect() {
    this.net = null
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  calculated({ detail }) {
    this.net = detail.netWeight
    this.update()
  }

  update() {
    const option = this.selectTarget.selectedOptions[0]
    const percent = parseFloat(option?.dataset.percent)
    const price = parseFloat(option?.dataset.canPrice)
    const chosen = percent > 0 && price > 0
    this.boxTarget.hidden = !chosen
    if (!chosen) return

    this.termsTarget.textContent = this.termsLabelValue
      .replace("%{percent}", `${percent.toString()} %`).replace("%{price}", `L ${this.money.format(price)}`)
    if (!(this.net > 0)) {
      this.cansTarget.textContent = "—"
      this.amountTarget.textContent = "—"
      return
    }
    const cans = this.net / this.canPoundsValue
    this.cansTarget.textContent = this.money.format(Math.round(cans * 100) / 100)
    this.amountTarget.textContent = `L ${this.money.format(Math.round(cans * price * percent) / 100)}`
  }
}
