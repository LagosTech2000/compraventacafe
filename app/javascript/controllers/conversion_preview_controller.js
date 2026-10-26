import { Controller } from "@hotwired/stimulus"

// A coffee conversion's weighing, as a preview (the server repeats it on
// save and its result is the one kept): the gross typed × the net/gross
// proportion of its coffee state is the net, and the net ÷ 125 the QQ.
//
// In «Nueva conversión» the state is the one chosen (what goes in); its
// gross in stock is shown, and typing more warns without stopping it. In
// the result the state is fixed (what came out).
export default class extends Controller {
  static targets = ["state", "gross", "net", "quintals", "ratio", "ratioSource", "toState", "available", "overStock"]
  static values = { ratios: Object, sources: Object, stock: Object, toStates: Object, state: String, quintalWeight: Number }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    const state = this.stateTargets.find((radio) => radio.checked)?.value || this.stateValue
    const ratio = parseFloat(this.ratiosValue[state])
    const gross = parseFloat(this.grossTarget.value)
    const net = gross > 0 && ratio > 0 ? this.round(gross * ratio) : null

    this.netTarget.textContent = net === null ? "—" : `${this.pounds.format(net)} lb`
    this.quintalsTarget.textContent = net === null ? "—" : this.pounds.format(this.round(net / this.quintalWeightValue))
    if (this.hasRatioTarget) this.ratioTarget.textContent = ratio > 0 ? ratio.toFixed(4) : "—"
    if (this.hasRatioSourceTarget) this.ratioSourceTarget.textContent = this.sourcesValue[state] || ""
    if (this.hasToStateTarget) this.toStateTarget.textContent = this.toStatesValue[state] || ""

    if (this.hasAvailableTarget) {
      const available = parseFloat(this.stockValue[state] ?? 0)
      this.availableTarget.textContent = `${this.pounds.format(available)} lb`
      this.overStockTarget.hidden = !(gross > available)
    }
  }

  round(value) {
    return Math.round(value * 100) / 100
  }
}
