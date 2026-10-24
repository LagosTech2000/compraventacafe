import { Controller } from "@hotwired/stimulus"

// Live preview of a truck's weighing (a shipment's local scale, or the
// buyer's). It mirrors PurchaseCalculation with the sacks counted, which
// the server repeats on save (the server's result is the one kept):
//
//   tare = sacks × 1 lb
//   parchment: net = (gross − tare) × (1 − humidity%) × (1 − damage%)
//   cherry:    net = (gross − tare) × yield
//   QQ = net ÷ 125
//
// Changing the coffee state swaps humidity and damage for the yield, with
// the new state's defaults. With an `originNet` value (the destination
// form), it also shows the difference with the local scale and marks it
// when it passes the tolerance.
export default class extends Controller {
  static targets = ["coffeeState", "gross", "sacks", "humidity", "damage", "yield", "parchmentField", "cherryField",
                    "tare", "net", "quintals", "difference", "differenceBox", "stockNotice"]
  static values = { tarePerSack: Number, quintalWeight: Number, defaults: Object, coffeeState: String,
                    originNet: Number, tolerance: Number, stock: Object, stockMessage: String }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  changeCoffeeState() {
    const state = this.state()
    const cherry = state === "cherry"
    this.parchmentFieldTargets.forEach((field) => this.toggle(field, !cherry))
    this.cherryFieldTargets.forEach((field) => this.toggle(field, cherry))
    const defaults = this.defaultsValue[state] || {}
    if (cherry) {
      if (this.hasYieldTarget) this.yieldTarget.value = defaults.yield_factor
    } else {
      if (this.hasHumidityTarget) this.humidityTarget.value = defaults.humidity_percent
      if (this.hasDamageTarget && this.damageTarget.value === "") this.damageTarget.value = defaults.damage_percent
    }
    this.update()
  }

  update() {
    const gross = parseFloat(this.grossTarget.value)
    const sacks = Math.trunc(parseFloat(this.sacksTarget.value))
    if (!(gross > 0) || !(sacks >= 0)) return this.show(null)

    const tare = sacks * this.tarePerSackValue
    const factor = this.netFactor()
    if (factor === null) return this.show(null, tare)

    const net = Math.round(Math.max((gross - tare) * factor, 0) * 100) / 100
    this.show(net, tare)
  }

  netFactor() {
    if (this.state() === "cherry") {
      const yieldFactor = parseFloat(this.yieldTarget.value)
      return yieldFactor > 0 ? yieldFactor : null
    }
    const humidity = parseFloat(this.humidityTarget.value)
    const damage = this.damageTarget.value.trim() === "" ? 0 : parseFloat(this.damageTarget.value)
    if (!(humidity >= 0) || !(damage >= 0)) return null
    return (1 - humidity / 100) * (1 - damage / 100)
  }

  state() {
    return this.hasCoffeeStateTarget ? this.coffeeStateTarget.value : this.coffeeStateValue
  }

  show(net, tare = null) {
    this.tareTarget.textContent = tare === null ? "—" : this.pounds.format(tare)
    this.netTarget.textContent = net === null ? "—" : this.pounds.format(net)
    this.quintalsTarget.textContent = net === null ? "—" : this.pounds.format(Math.round((net / this.quintalWeightValue) * 100) / 100)
    this.showDifference(net)
    this.showStock(net)
  }

  // The buyer's net against the local one: −lb (−%).
  showDifference(net) {
    if (!this.hasDifferenceTarget) return
    if (net === null || !(this.originNetValue > 0)) {
      this.differenceTarget.textContent = "—"
      this.differenceBoxTarget.dataset.overTolerance = "false"
      return
    }
    const difference = Math.round((net - this.originNetValue) * 100) / 100
    const percent = Math.round((difference * 100 / this.originNetValue) * 100) / 100
    const sign = (value) => (value > 0 ? "+" : value < 0 ? "−" : "")
    this.differenceTarget.textContent =
      `${sign(difference)}${this.pounds.format(Math.abs(difference))} lb (${sign(percent)}${this.pounds.format(Math.abs(percent))} %)`
    const over = this.hasToleranceValue && this.toleranceValue > 0 && Math.abs(percent) > this.toleranceValue
    this.differenceBoxTarget.dataset.overTolerance = over ? "true" : "false"
  }

  // Leaving with more than the stock of that state: a notice, not a block.
  showStock(net) {
    if (!this.hasStockNoticeTarget) return
    const available = this.stockValue[this.state()]
    const over = net !== null && available !== undefined && net > available
    this.stockNoticeTarget.hidden = !over
    if (over) this.stockNoticeTarget.textContent = this.stockMessageValue.replace("%{stock}", this.pounds.format(available))
  }

  toggle(field, visible) {
    field.hidden = !visible
    field.querySelectorAll("input").forEach((input) => { input.disabled = !visible })
  }
}
