import { Controller } from "@hotwired/stimulus"

// Live preview of the purchase calculation while typing. It mirrors
// PurchaseCalculation (Ruby), which stays the source of truth: the server
// recalculates on save.
//
// Changing the coffee state swaps the inputs: parchment uses humidity and
// damage, cherry uses the yield. The new state's defaults (PurchaseDefaults)
// replace what was typed in them.
//
// By weighings, the gross weight is the sum of the weighings (read only) and
// the tare is 1 lb per sack counted in them. Weighings are added from a
// <template>; a saved one is marked for removal, a new one is dropped. In one
// figure, the weighings are hidden and disabled (not sent).
export default class extends Controller {
  static targets = ["coffeeState", "gross", "grossHelp", "humidity", "damage", "yield", "price",
                    "parchmentField", "cherryField", "sacks", "tare", "damageWeight", "damageAmount", "netWeight", "quintals", "total",
                    "weightMode", "weighingsSection", "weighings", "weighingTemplate", "weighing",
                    "weighingDestroy", "weighingGross", "weighingSacks", "damageTypes", "damageType"]
  static values = { sackWeight: Number, tarePerSack: Number, quintalWeight: Number, defaults: Object,
                    damageTypesMessage: String }

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

  changeWeightMode() {
    const byWeighings = this.byWeighings()
    this.weighingsSectionTarget.hidden = !byWeighings
    this.grossHelpTarget.hidden = !byWeighings
    this.grossTarget.readOnly = byWeighings
    this.weighingTargets.forEach((weighing) => this.enableWeighing(weighing, byWeighings))

    if (byWeighings && !this.visibleWeighings().length) {
      this.addWeighing()
    } else if (!byWeighings) {
      this.grossTarget.focus()
    }
    this.update()
  }

  addWeighing() {
    const html = this.weighingTemplateTarget.innerHTML.replace(/NEW_RECORD/g, String(Date.now()))
    this.weighingsTarget.insertAdjacentHTML("beforeend", html)
    this.weighingTargets[this.weighingTargets.length - 1].querySelector("input[type='number']")?.focus()
    this.update()
  }

  removeWeighing(event) {
    const weighing = event.target.closest("[data-purchase-calculator-target~='weighing']")
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
    this.showDamageTypes()
    let gross = parseFloat(this.grossTarget.value)
    let sacks = null
    if (this.byWeighings()) {
      gross = 0
      sacks = 0
      this.visibleWeighings().forEach((weighing) => {
        gross += this.number(this.field(weighing, "weighingGross").value)
        sacks += Math.trunc(this.number(this.field(weighing, "weighingSacks").value))
      })
      gross = Math.round(gross * 100) / 100
      this.grossTarget.value = gross > 0 ? gross.toFixed(2) : ""
    }

    const price = parseFloat(this.priceTarget.value)
    if (!(gross > 0)) return this.show("—", "—", "—", "—", "—", "—", "—")

    // Counted sacks (by weighings) or the ones the gross weight holds.
    const tare = sacks === null ? Math.ceil(gross / this.sackWeightValue) * this.tarePerSackValue : sacks * this.tarePerSackValue
    if (sacks === null) sacks = gross / this.sackWeightValue

    // Sacks and tare only need the gross weight: they stay while the rest is incomplete.
    const factor = this.netFactor()
    if (factor === null) return this.show(this.pounds.format(sacks), this.pounds.format(tare), "—", "—", "—", "—", "—")

    const net = Math.round(Math.max((gross - tare) * factor, 0) * 100) / 100
    const quintals = Math.round((net / this.quintalWeightValue) * 100) / 100
    const damage = this.coffeeStateTarget.value === "cherry" ? 0 :
      Math.round(Math.max((gross - tare) * (1 - parseFloat(this.humidityTarget.value) / 100), 0) *
                 (this.damagePercent() / 100) * 100) / 100
    const money = (value) => price > 0 ? `L ${this.pounds.format(Math.round(value * price * 100) / 100)}` : "—"

    this.show(this.pounds.format(sacks), this.pounds.format(tare), this.pounds.format(damage), money(damage),
              this.pounds.format(net), this.pounds.format(quintals), money(net), net)
  }

  // Share of the weight after tare that counts, or null while incomplete.
  netFactor() {
    if (this.coffeeStateTarget.value === "cherry") {
      const yieldFactor = parseFloat(this.yieldTarget.value)
      return yieldFactor > 0 ? yieldFactor : null
    }

    const humidity = parseFloat(this.humidityTarget.value)
    const damage = this.damagePercent()
    if (!(humidity >= 0) || damage === null) return null
    return (1 - humidity / 100) * (1 - damage / 100)
  }

  // Parchment with damage above 0 asks for its kinds: at least one, which
  // the browser says before sending (the server checks it too).
  showDamageTypes() {
    if (!this.hasDamageTypesTarget) return
    const damaged = this.coffeeStateTarget.value !== "cherry" && this.damagePercent() > 0
    this.damageTypesTarget.hidden = !damaged
    this.damageTypesTarget.querySelectorAll("input").forEach((input) => { input.disabled = !damaged })
    const chosen = this.damageTypeTargets.some((box) => box.checked)
    this.damageTypeTargets[0]?.setCustomValidity(damaged && !chosen ? this.damageTypesMessageValue : "")
  }

  // An empty damage field means no damage (0 %), as the server takes it.
  damagePercent() {
    if (this.damageTarget.value.trim() === "") return 0
    const damage = parseFloat(this.damageTarget.value)
    return damage >= 0 ? damage : null
  }

  byWeighings() {
    return this.weightModeTargets.find((radio) => radio.checked)?.value === "weighings"
  }

  visibleWeighings() {
    return this.weighingTargets.filter((weighing) => !weighing.hidden)
  }

  // A weighing marked for removal only sends its id and removal mark.
  enableWeighing(weighing, enabled) {
    weighing.querySelectorAll("input").forEach((input) => {
      const keep = input.name.endsWith("[id]") || input.name.endsWith("[_destroy]")
      input.disabled = !enabled || (weighing.hidden && !keep)
    })
  }

  field(element, name) {
    return element.querySelector(`[data-purchase-calculator-target~='${name}']`)
  }

  number(value) {
    const parsed = parseFloat(value)
    return parsed > 0 ? parsed : 0
  }

  toggle(field, visible) {
    field.hidden = !visible
    field.querySelectorAll("input").forEach((input) => { input.disabled = !visible })
  }

  // `netWeight` (a number, or null while incomplete) goes out in a
  // "purchase-calculator:calculated" event: the hauler's commission follows it.
  show(sacks, tare, damage, damageAmount, net, quintals, total, netWeight = null) {
    this.dispatch("calculated", { detail: { netWeight } })
    this.sacksTarget.textContent = sacks
    this.tareTarget.textContent = tare
    this.damageWeightTarget.textContent = damage
    this.damageAmountTarget.textContent = damageAmount
    this.netWeightTarget.textContent = net
    this.quintalsTarget.textContent = quintals
    this.totalTarget.textContent = total
  }
}
