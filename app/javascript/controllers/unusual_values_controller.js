import { Controller } from "@hotwired/stimulus"

// Warns, without stopping anything, when a purchase value looks like a typo
// (Fernando, 2026-10-25): humidity or yield more than `percent` away from
// the coffee state's starting value, or a price that far from the day's
// average for that state (when there are purchases of it today).
export default class extends Controller {
  static targets = ["state", "humidity", "yieldFactor", "price", "humidityWarning", "yieldWarning", "priceWarning"]
  static values = { defaults: Object, averages: Object, percent: Number, states: Object, messages: Object }

  connect() {
    this.decimal = new Intl.NumberFormat("es-HN", { maximumFractionDigits: 4 })
    this.money = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.check()
  }

  check() {
    const state = this.stateTarget.value
    const defaults = this.defaultsValue[state] || {}
    const stateName = this.statesValue[state] || ""

    this.warn(this.humidityWarningTarget, state !== "cherry" && this.off(this.humidityTarget.value, defaults.humidity_percent),
      (value, normal, high) => this.text("humidity", { value: this.decimal.format(value), normal: this.decimal.format(normal), state: stateName, high }))
    this.warn(this.yieldWarningTarget, state === "cherry" && this.off(this.yieldFactorTarget.value, defaults.yield_factor),
      (value, normal, high) => this.text("yield", { value: this.decimal.format(value), normal: this.decimal.format(normal), high }))

    const average = this.averagesValue[state]
    this.warn(this.priceWarningTarget, average && this.off(this.priceTarget.value, average),
      (value, normal, high) => this.text("price", {
        percent: Math.round(Math.abs(value - normal) / normal * 100), state: stateName, average: this.money.format(normal), high
      }))
  }

  // [value, normal, high] when the value is too far from the normal one.
  off(raw, normal) {
    const value = parseFloat(raw)
    normal = parseFloat(normal)
    if (!(value > 0) || !(normal > 0)) return null
    return Math.abs(value - normal) / normal * 100 > this.percentValue ? [value, normal, value > normal] : null
  }

  warn(target, found, message) {
    target.hidden = !found
    target.textContent = found ? message(...found) : ""
  }

  text(key, { high, ...values }) {
    const template = this.messagesValue[key][high ? "high" : "low"]
    return Object.entries(values).reduce((text, [name, value]) => text.replace(`%{${name}}`, value), template)
  }
}
