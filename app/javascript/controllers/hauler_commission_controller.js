import { Controller } from "@hotwired/stimulus"

// Purchase form: the commission of the carrero chosen (Hauler), as a
// preview: net pounds × their price per pound. Each option of the select
// carries its hauler's price per pound (the purchase's own, for the hauler
// already on it). The net weight comes from purchase-calculator's
// "calculated" event; the server calculates it again.
export default class extends Controller {
  static targets = ["select", "box", "terms", "amount"]
  static values = { termsLabel: String }

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
    this.boxTarget.hidden = !(perPound > 0)
    if (this.boxTarget.hidden) return

    const net = this.net > 0 ? this.net : null
    this.termsTarget.textContent = this.termsLabelValue.replace("%{price}", `L ${this.price.format(perPound)}`)
    this.amountTarget.textContent = net === null ? "—" : `L ${this.money.format(Math.round(net * perPound * 100) / 100)}`
  }
}
