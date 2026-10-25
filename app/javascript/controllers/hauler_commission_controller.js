import { Controller } from "@hotwired/stimulus"

// Purchase form: the commission of the carrero chosen (Hauler), as a
// preview: net pounds × their price per pound. Each option of the select
// carries its hauler's price per pound; the hauler already on a purchase
// from before 2026-10-24 carries the percent and can price it kept
// (cans = net ÷ the pounds of a can; commission = cans × can price ×
// percent). The net weight comes from purchase-calculator's "calculated"
// event; the server calculates it again.
export default class extends Controller {
  static targets = ["select", "box", "terms", "amount"]
  static values = { canPounds: Number, termsLabel: String, legacyLabel: String }

  connect() {
    this.net = null
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.price = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 4 })
    this.update()
  }

  calculated({ detail }) {
    this.net = detail.netWeight
    this.update()
  }

  update() {
    const data = this.selectTarget.selectedOptions[0]?.dataset || {}
    const perPound = parseFloat(data.pricePerPound)
    const percent = parseFloat(data.percent)
    const canPrice = parseFloat(data.canPrice)
    const byCans = !(perPound > 0) && percent > 0 && canPrice > 0
    this.boxTarget.hidden = !(perPound > 0 || byCans)
    if (this.boxTarget.hidden) return

    const net = this.net > 0 ? this.net : null
    if (byCans) {
      const cans = net === null ? null : net / this.canPoundsValue
      this.termsTarget.textContent = this.legacyLabelValue
        .replace("%{percent}", `${percent.toString()} %`).replace("%{price}", `L ${this.money.format(canPrice)}`)
      this.amountTarget.textContent = cans === null ? "—" : `L ${this.money.format(Math.round(cans * canPrice * percent) / 100)}`
    } else {
      this.termsTarget.textContent = this.termsLabelValue.replace("%{price}", `L ${this.price.format(perPound)}`)
      this.amountTarget.textContent = net === null ? "—" : `L ${this.money.format(Math.round(net * perPound * 100) / 100)}`
    }
  }
}
