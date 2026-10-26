import { Controller } from "@hotwired/stimulus"

// A coffee conversion's weighing, as a preview (the server repeats it on
// save and its result is the one kept); the net ÷ 125 is the QQ.
//
// In «Nueva conversión» (what goes in) the net is the gross typed × the
// net/gross proportion of the state chosen; its gross in stock is shown,
// and typing more warns without stopping it. In the result (what came out)
// it is weighed like a purchase: (gross − 1 lb × sack) × (1 − humidity) ×
// (1 − damage), and it says how many net pounds more or less than what went in.
export default class extends Controller {
  static targets = ["state", "gross", "net", "quintals", "toState", "available", "overStock", "sacks", "humidity", "damage", "difference"]
  static values = { ratios: Object, stock: Object, toStates: Object, state: String, quintalWeight: Number, inputNet: Number }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    const state = this.stateTargets.find((radio) => radio.checked)?.value || this.stateValue
    const gross = parseFloat(this.grossTarget.value)
    const net = this.hasHumidityTarget ? this.weighed(gross) : this.byRatio(gross, parseFloat(this.ratiosValue[state]))

    this.netTarget.textContent = net === null ? "—" : `${this.pounds.format(net)} lb`
    this.quintalsTarget.textContent = net === null ? "—" : this.pounds.format(this.round(net / this.quintalWeightValue))
    if (this.hasToStateTarget) this.toStateTarget.textContent = this.toStatesValue[state] || ""

    if (this.hasDifferenceTarget) this.showDifference(net)

    if (this.hasAvailableTarget) {
      const available = parseFloat(this.stockValue[state] ?? 0)
      this.availableTarget.textContent = `${this.pounds.format(available)} lb`
      this.overStockTarget.hidden = !(gross > available)
    }
  }

  byRatio(gross, ratio) {
    return gross > 0 && ratio > 0 ? this.round(gross * ratio) : null
  }

  weighed(gross) {
    const sacks = parseInt(this.sacksTarget.value, 10)
    const humidity = parseFloat(this.humidityTarget.value)
    const damage = parseFloat(this.damageTarget.value) || 0
    if (!(gross > 0 && sacks > 0 && humidity >= 0)) return null
    return Math.max(this.round((gross - sacks) * (1 - humidity / 100) * (1 - damage / 100)), 0)
  }

  // "37.66 lb netas más que las que entraron (+7.7 %)"
  showDifference(net) {
    const target = this.differenceTarget
    if (net === null) { target.textContent = ""; return }
    const difference = this.round(net - this.inputNetValue)
    const percent = this.inputNetValue > 0 ? Math.round(difference / this.inputNetValue * 1000) / 10 : 0
    const key = difference > 0 ? "more" : difference < 0 ? "less" : "same"
    target.textContent = target.dataset[key]
      .replace("%{pounds}", this.pounds.format(Math.abs(difference)))
      .replace("%{percent}", new Intl.NumberFormat("es-HN", { maximumFractionDigits: 1 }).format(Math.abs(percent)))
  }

  round(value) {
    return Math.round(value * 100) / 100
  }
}
