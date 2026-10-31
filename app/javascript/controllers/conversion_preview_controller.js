import { Controller } from "@hotwired/stimulus"

// A process's weighing, as a preview (the server repeats it on save and its
// result is the one kept); the net ÷ 125 is the QQ.
//
// In «Procesar café» (what goes in) the net is the gross typed × the
// net/gross proportion of the state chosen; its gross in stock (of the
// warehouse chosen) is shown, and typing more warns without stopping it;
// with none at all, it says so and the form is not sent (client,
// 2026-10-30: the server checks it too). Each process has its own places
// (client, 2026-10-30): the list shows the ones of the state chosen, and
// «Nuevo lugar» opens with that process checked.
// The estimate says how many gross pounds should come out (gross × the
// estimated %), and below it, what the processes of that state really gave.
// Changing the state puts its starting estimate and hides the humidity of
// cherry (it has none).
//
// In the result (what came out) it is weighed like a purchase: (gross − 1
// lb × sack) × (1 − humidity) × (1 − damage), and it says how many net
// pounds more or less than what went in, the real yield and how far it is
// from the estimate.
export default class extends Controller {
  static targets = ["state", "gross", "net", "quintals", "toState", "available", "overStock", "sacks", "humidity", "damage", "difference", "warehouse",
                    "estimate", "estimatedOutput", "average", "humidityField", "realYield", "estimateDifference",
                    "site", "noSites", "newSite", "noStock", "submit"]
  static values = { ratios: Object, stock: Object, toStates: Object, state: String, quintalWeight: Number, inputNet: Number,
                    defaults: Object, averages: Object, inputGross: Number, estimatedGross: Number }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.percent = new Intl.NumberFormat("es-HN", { maximumFractionDigits: 2 })
    this.update()
  }

  changeState() {
    const state = this.currentState()
    if (this.hasEstimateTarget && this.defaultsValue[state] !== undefined) this.estimateTarget.value = this.defaultsValue[state]
    if (this.hasHumidityFieldTarget) {
      const cherry = state === "cherry"
      this.humidityFieldTarget.hidden = cherry
      this.humidityFieldTarget.querySelectorAll("input").forEach((input) => { input.disabled = cherry })
    }
    this.filterSites()
    this.update()
  }

  // Only the places of the process chosen; a place of the other one is unselected.
  filterSites() {
    if (!this.hasSiteTarget) return
    const state = this.currentState()
    let any = false
    for (const option of this.siteTarget.options) {
      if (!option.value) continue
      const fits = (option.dataset.fromStates || "").split(" ").includes(state)
      option.hidden = !fits
      option.disabled = !fits
      any ||= fits
    }
    if (this.siteTarget.selectedOptions[0]?.disabled) this.siteTarget.value = ""
    if (this.hasNoSitesTarget) this.noSitesTarget.hidden = any
    if (this.hasNewSiteTarget) {
      const url = new URL(this.newSiteTarget.href, window.location.origin)
      url.searchParams.set("from_state", state)
      this.newSiteTarget.href = url.pathname + url.search
    }
  }

  // A place created in the modal: shown only if it does this process.
  siteTargetConnected() {
    this.siteObserver = new MutationObserver(() => this.filterSites())
    this.siteObserver.observe(this.siteTarget, { childList: true })
  }

  siteTargetDisconnected() {
    this.siteObserver?.disconnect()
  }

  currentState() {
    return this.stateTargets.find((radio) => radio.checked)?.value || this.stateValue
  }

  update() {
    const state = this.currentState()
    const gross = parseFloat(this.grossTarget.value)
    const net = this.hasHumidityTarget ? this.weighed(gross) : this.byRatio(gross, parseFloat(this.ratiosValue[state]))

    this.netTarget.textContent = net === null ? "—" : `${this.pounds.format(net)} lb`
    this.quintalsTarget.textContent = net === null ? "—" : this.pounds.format(this.round(net / this.quintalWeightValue))
    if (this.hasToStateTarget) this.toStateTarget.textContent = this.toStatesValue[state] || ""

    if (this.hasDifferenceTarget) this.showDifference(net)
    if (this.hasEstimatedOutputTarget) this.showEstimate(gross, state)
    if (this.hasRealYieldTarget) this.showRealYield(gross)

    if (this.hasAvailableTarget) {
      const stock = this.hasWarehouseTarget ? (this.stockValue[this.warehouseTarget.value] || {}) : this.stockValue
      const available = parseFloat(stock[state] ?? 0)
      this.availableTarget.textContent = `${this.pounds.format(available)} lb`
      const empty = !(available > 0)
      this.overStockTarget.hidden = empty || !(gross > available)
      if (this.hasNoStockTarget) this.noStockTarget.hidden = !empty
      if (this.hasSubmitTarget) this.submitTarget.disabled = empty
    }
  }

  // What should come out, and what the processes of this state really gave.
  showEstimate(gross, state) {
    const estimate = parseFloat(this.estimateTarget.value)
    this.estimatedOutputTarget.textContent = gross > 0 && estimate > 0 ? `${this.pounds.format(this.round(gross * estimate / 100))} lb` : "—"
    if (!this.hasAverageTarget) return
    const average = this.averagesValue[state]
    this.averageTarget.textContent = average === null || average === undefined
      ? this.averageTarget.dataset.none
      : this.averageTarget.dataset.some.replace("%{percent}", this.percent.format(average))
  }

  // The result: what it really gave (gross out per 100 in) and how far from the estimate.
  showRealYield(gross) {
    if (!(gross > 0) || !(this.inputGrossValue > 0)) {
      this.realYieldTarget.textContent = "—"
      if (this.hasEstimateDifferenceTarget) this.estimateDifferenceTarget.textContent = ""
      return
    }
    this.realYieldTarget.textContent = `${this.percent.format(this.round(gross * 100 / this.inputGrossValue))} %`
    if (!this.hasEstimateDifferenceTarget || !(this.estimatedGrossValue > 0)) return
    const difference = this.round(gross - this.estimatedGrossValue)
    const target = this.estimateDifferenceTarget
    const key = difference > 0 ? "more" : difference < 0 ? "less" : "same"
    target.textContent = target.dataset[key].replace("%{pounds}", this.pounds.format(Math.abs(difference)))
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
