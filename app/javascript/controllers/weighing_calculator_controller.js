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
// the new state's defaults. By weighings (the local scale, as in the
// purchases), the gross weight and the sacks are the sums of the weighings
// (read only); weighings are added from a <template>, a saved one is marked
// for removal and a new one dropped. With an `originNet` value (the destination
// form), it also shows the difference with the local scale and marks it
// when it passes the tolerance.
export default class extends Controller {
  static targets = ["coffeeState", "gross", "sacks", "humidity", "damage", "yield", "parchmentField", "cherryField",
                    "tare", "net", "quintals", "difference", "differenceBox", "stockNotice",
                    "weightMode", "weighingsSection", "weighings", "weighingTemplate", "weighing",
                    "weighingGross", "weighingSacks", "weighingDestroy", "sumHelp", "warehouse"]
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

  changeWeightMode() {
    const byWeighings = this.byWeighings()
    this.weighingsSectionTarget.hidden = !byWeighings
    if (this.hasSumHelpTarget) this.sumHelpTarget.hidden = !byWeighings
    this.grossTarget.readOnly = byWeighings
    this.sacksTarget.readOnly = byWeighings
    this.weighingTargets.forEach((weighing) => this.enableWeighing(weighing, byWeighings))
    if (byWeighings && !this.visibleWeighings().length) this.addWeighing()
    else if (!byWeighings) this.grossTarget.focus()
    this.update()
  }

  addWeighing() {
    const html = this.weighingTemplateTarget.innerHTML.replace(/NEW_RECORD/g, String(Date.now()))
    this.weighingsTarget.insertAdjacentHTML("beforeend", html)
    this.weighingTargets[this.weighingTargets.length - 1].querySelector("input[type='number']")?.focus()
    this.update()
  }

  removeWeighing(event) {
    const weighing = event.target.closest("[data-weighing-calculator-target~='weighing']")
    if (weighing.querySelector("input[name$='[id]']")) {
      this.field(weighing, "weighingDestroy").value = "1"
      weighing.hidden = true
      this.enableWeighing(weighing, true)
    } else {
      weighing.remove()
    }
    this.update()
  }

  update() {
    if (this.byWeighings()) this.sumWeighings()
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

  checkStock() {
    this.update()
  }

  // Leaving with more than the stock of that state (in the chosen
  // warehouse, when there is one to choose): a notice, not a block.
  showStock(net) {
    if (!this.hasStockNoticeTarget) return
    const stock = this.hasWarehouseTarget ? (this.stockValue[this.warehouseTarget.value] || {}) : this.stockValue
    const available = stock[this.state()]
    const over = net !== null && available !== undefined && net > available
    this.stockNoticeTarget.hidden = !over
    if (over) this.stockNoticeTarget.textContent = this.stockMessageValue.replace("%{stock}", this.pounds.format(available))
  }

  byWeighings() {
    return this.weightModeTargets.find((radio) => radio.checked)?.value === "weighings"
  }

  visibleWeighings() {
    return this.weighingTargets.filter((weighing) => !weighing.hidden)
  }

  // The local gross weight and sacks are the sums of the weighings.
  sumWeighings() {
    let gross = 0
    let sacks = 0
    this.visibleWeighings().forEach((weighing) => {
      gross += this.positive(this.field(weighing, "weighingGross").value)
      sacks += Math.trunc(this.positive(this.field(weighing, "weighingSacks").value))
    })
    gross = Math.round(gross * 100) / 100
    this.grossTarget.value = gross > 0 ? gross.toFixed(2) : ""
    this.sacksTarget.value = sacks > 0 ? String(sacks) : ""
  }

  // A weighing marked for removal only sends its id and removal mark.
  enableWeighing(weighing, enabled) {
    weighing.querySelectorAll("input").forEach((input) => {
      const keep = input.name.endsWith("[id]") || input.name.endsWith("[_destroy]")
      input.disabled = !enabled || (weighing.hidden && !keep)
    })
  }

  field(element, name) {
    return element.querySelector(`[data-weighing-calculator-target~='${name}']`)
  }

  positive(value) {
    const parsed = parseFloat(value)
    return parsed > 0 ? parsed : 0
  }

  toggle(field, visible) {
    field.hidden = !visible
    field.querySelectorAll("input").forEach((input) => { input.disabled = !visible })
  }
}
