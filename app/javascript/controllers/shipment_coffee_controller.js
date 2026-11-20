import { Controller } from "@hotwired/stimulus"

// «¿Qué café lleva?» (Fernando, 2026-11-18): only the invoices of the coffee
// state and warehouse chosen in the shipment form show (one of another is
// unmarked); shortcuts mark today's purchases, the ones since the last
// shipment of that coffee, all or none; and what it carries (these invoices
// and the lots marked below) shows against the local scale's gross pounds.
export default class extends Controller {
  static targets = ["item", "empty", "total", "percent"]
  static values = { today: String, lastDepartures: Object, texts: Object }

  connect() {
    this.form = this.element.closest("form")
    this.onChange = (event) => {
      if (event.target.matches("[name='shipment[coffee_state]'], [name='shipment[warehouse_id]']")) this.filter()
      else this.sum()
    }
    this.form?.addEventListener("change", this.onChange)
    this.form?.addEventListener("input", this.onChange)
    this.pounds = new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.filter()
  }

  disconnect() {
    this.form?.removeEventListener("change", this.onChange)
    this.form?.removeEventListener("input", this.onChange)
  }

  current() {
    const states = [ ...(this.form?.querySelectorAll("[name='shipment[coffee_state]']") || []) ]
    const state = states.find((field) => field.type !== "radio" || field.checked)
    return { state: state?.value || "", warehouse: this.form?.querySelector("[name='shipment[warehouse_id]']")?.value || "" }
  }

  shown() {
    return this.itemTargets.filter((item) => !item.hidden)
  }

  filter() {
    const { state, warehouse } = this.current()
    this.itemTargets.forEach((item) => {
      const fits = item.dataset.coffeeState === state && item.dataset.warehouseId === warehouse
      item.hidden = !fits
      const box = this.box(item)
      if (!fits) box.checked = false
      box.disabled = !fits
    })
    this.emptyTarget.hidden = this.shown().length > 0
    this.sum()
  }

  pick(event) {
    const shortcut = event.currentTarget.dataset.shortcut
    const { state, warehouse } = this.current()
    const last = this.lastDeparturesValue[`${state}|${warehouse}`]
    this.shown().forEach((item) => {
      let mark = shortcut === "all"
      if (shortcut === "today") mark = item.dataset.day === this.todayValue
      if (shortcut === "since_last") mark = !last || new Date(item.dataset.entered) > new Date(last)
      this.box(item).checked = mark
    })
    this.sum()
  }

  box(item) {
    return item.querySelector("input[type=checkbox]")
  }

  // Its % field goes with its box: sent only when marked.
  percentOf(item) {
    return item.querySelector("[data-shipment-coffee-target='percent']")
  }

  // What a marked invoice carries: its % of the invoice's pounds.
  share(item) {
    const field = this.percentOf(item)
    const percent = parseFloat(field?.value)
    if (!field || !(percent > 0)) return { gross: 0, net: 0 }
    return {
      gross: (parseFloat(item.dataset.invoiceGross) || 0) * percent / 100,
      net: (parseFloat(item.dataset.invoiceNet) || 0) * percent / 100
    }
  }

  // These invoices and the lots marked in the form, against the local scale.
  sum() {
    this.itemTargets.forEach((item) => {
      const field = this.percentOf(item)
      if (field) field.disabled = item.hidden || !this.box(item).checked
    })
    const marked = this.shown().filter((item) => this.box(item).checked)
    const lots = [ ...(this.form?.querySelectorAll("[data-batch-picker-target='item']") || []) ]
      .filter((item) => !item.hidden && item.querySelector("input[type=checkbox]")?.checked)
    const shares = marked.map((item) => this.share(item))
      .concat(lots.map((item) => ({ gross: parseFloat(item.dataset.gross) || 0, net: parseFloat(item.dataset.net) || 0 })))
    const gross = shares.reduce((total, share) => total + share.gross, 0)
    const net = shares.reduce((total, share) => total + share.net, 0)
    if (!(gross > 0)) {
      this.totalTarget.textContent = this.textsValue.nothing
      this.totalTarget.classList.remove("text-danger")
      return
    }
    let text = this.textsValue.carries.replace("%{gross}", this.pounds.format(gross)).replace("%{net}", this.pounds.format(net))
    const local = parseFloat(this.form?.querySelector("[name='shipment[origin_gross_weight]']")?.value)
    if (local > 0) {
      const difference = Math.round((local - gross) * 100) / 100
      const percent = Math.round((difference * 10000) / gross) / 100
      const sign = (value) => (value > 0 ? "+" : value < 0 ? "−" : "")
      text += " " + this.textsValue.against
        .replace("%{gross}", `${sign(difference)}${this.pounds.format(Math.abs(difference))}`)
        .replace("%{percent}", `${sign(percent)}${this.pounds.format(Math.abs(percent))}`)
    }
    this.totalTarget.textContent = text
  }
}
