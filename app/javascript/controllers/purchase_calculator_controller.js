import { Controller } from "@hotwired/stimulus"

// Live preview of the purchase calculation while typing. It mirrors
// PurchaseCalculation (Ruby), which stays the source of truth: the server
// recalculates on save.
//
// Changing the coffee state swaps the inputs: parchment uses humidity and
// damage, cherry uses the yield. The new state's defaults (PurchaseDefaults)
// replace what was typed in them.
export default class extends Controller {
  static targets = ["coffeeState", "gross", "humidity", "damage", "yield", "price",
                    "parchmentField", "cherryField", "sacks", "tare", "damageWeight", "netWeight", "quintals", "total"]
  static values = { sackWeight: Number, tarePerSack: Number, quintalWeight: Number, defaults: Object }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  changeCoffeeState() {
    const state = this.coffeeStateTarget.value
    const cherry = state === "cherry"
    this.parchmentFieldTargets.forEach((field) => this.toggle(field, !cherry))
    this.cherryFieldTargets.forEach((field) => this.toggle(field, cherry))

    const defaults = this.defaultsValue[state] || {}
    if (cherry) {
      this.yieldTarget.value = defaults.yield_factor
    } else {
      this.humidityTarget.value = defaults.humidity_percent
      if (this.damageTarget.value === "") this.damageTarget.value = defaults.damage_percent
    }
    this.update()
  }

  update() {
    const gross = parseFloat(this.grossTarget.value)
    const price = parseFloat(this.priceTarget.value)
    const factor = this.netFactor()

    if (!(gross > 0) || factor === null) return this.show("—", "—", "—", "—", "—", "—")

    const sacks = gross / this.sackWeightValue
    const tare = Math.ceil(sacks) * this.tarePerSackValue
    const net = Math.round(Math.max((gross - tare) * factor, 0) * 100) / 100
    const quintals = Math.round((net / this.quintalWeightValue) * 100) / 100
    const damage = this.coffeeStateTarget.value === "cherry" ? 0 :
      Math.round(Math.max((gross - tare) * (1 - parseFloat(this.humidityTarget.value) / 100), 0) *
                 (parseFloat(this.damageTarget.value) / 100) * 100) / 100
    const total = price > 0 ? `L ${this.pounds.format(Math.round(net * price * 100) / 100)}` : "—"

    this.show(this.pounds.format(sacks), this.pounds.format(tare), this.pounds.format(damage),
              this.pounds.format(net), this.pounds.format(quintals), total)
  }

  // Share of the weight after tare that counts, or null while incomplete.
  netFactor() {
    if (this.coffeeStateTarget.value === "cherry") {
      const yieldFactor = parseFloat(this.yieldTarget.value)
      return yieldFactor > 0 ? yieldFactor : null
    }

    const humidity = parseFloat(this.humidityTarget.value)
    const damage = parseFloat(this.damageTarget.value)
    if (!(humidity >= 0) || !(damage >= 0)) return null
    return (1 - humidity / 100) * (1 - damage / 100)
  }

  toggle(field, visible) {
    field.hidden = !visible
    field.querySelectorAll("input").forEach((input) => { input.disabled = !visible })
  }

  show(sacks, tare, damage, net, quintals, total) {
    this.sacksTarget.textContent = sacks
    this.tareTarget.textContent = tare
    this.damageWeightTarget.textContent = damage
    this.netWeightTarget.textContent = net
    this.quintalsTarget.textContent = quintals
    this.totalTarget.textContent = total
  }
}
