import { Controller } from "@hotwired/stimulus"

// The lot of a new invoice in «Facturar compras» (Fernando, 2026-11-13:
// «que se pueda asignar el lote desde facturar o el porcentaje mostrando el
// cálculo live»). As purchases are marked, only the lots of their coffee
// state and warehouse can be chosen; the percent shows the gross and net
// pounds it takes of the marked purchases and what is left under the lot's
// limit. Past the limit, the percent field stops the form with the most
// that fits. The server checks it again (CoffeeBatchInvoice).
export default class extends Controller {
  static targets = ["purchase", "box", "lot", "percentField", "percent", "result"]

  connect() {
    if (!this.hasLotTarget) return

    this.texts = JSON.parse(this.boxTarget.dataset.texts)
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.element.addEventListener("change", this.update)
    this.element.addEventListener("input", this.update)
    this.update()
  }

  disconnect() {
    this.element.removeEventListener("change", this.update)
    this.element.removeEventListener("input", this.update)
  }

  update = () => {
    if (!this.hasLotTarget) return

    const marked = this.purchaseTargets.filter((row) => row.querySelector("input[type=checkbox]")?.checked)
    const states = new Set(marked.map((row) => row.dataset.state))
    const warehouses = new Set(marked.map((row) => row.dataset.warehouse))
    const fits = marked.length > 0 && states.size === 1 && warehouses.size === 1
    const [state] = states
    const [warehouse] = warehouses

    let available = 0
    Array.from(this.lotTarget.options).forEach((option) => {
      if (!option.value) return
      const ok = fits && option.dataset.state === state && option.dataset.warehouse === warehouse
      option.disabled = !ok
      option.hidden = !ok
      if (ok) available += 1
    })
    if (this.lotTarget.selectedOptions[0]?.disabled) this.lotTarget.value = ""
    this.lotTarget.disabled = available === 0

    const lot = this.lotTarget.selectedOptions[0]
    const chosen = Boolean(lot?.value)
    this.percentFieldTarget.hidden = !chosen
    this.percentTarget.setCustomValidity("")

    if (marked.length === 0) return this.show(this.texts.no_purchases)
    if (!fits) return this.show(this.texts.mixed)
    if (available === 0) return this.show(this.texts.none_fit)
    if (!chosen) return this.show("")

    const gross = marked.reduce((sum, row) => sum + parseFloat(row.dataset.gross), 0)
    const net = marked.reduce((sum, row) => sum + parseFloat(row.dataset.net), 0)
    const percent = parseFloat(this.percentTarget.value) || 0
    const takes = Math.round(gross * percent) / 100
    const takesNet = Math.round(net * percent) / 100
    const room = parseFloat(lot.dataset.room)
    const lines = [this.fill(this.texts.takes, { gross: takes, net: takesNet })]

    if (takes > room + 0.005) {
      const max = Math.floor((room / gross) * 10000) / 100
      const message = this.fill(this.texts.over, { over: takes - room, max: max.toFixed(2) })
      lines.push(message)
      this.percentTarget.setCustomValidity(message)
      this.show(lines, true)
    } else {
      lines.push(this.fill(this.texts.room, { room, left: room - takes }))
      this.show(lines)
    }
  }

  show(lines, over = false) {
    this.resultTarget.replaceChildren(...[lines].flat().filter(Boolean).map((text) => {
      const line = document.createElement("span")
      line.className = "block"
      line.textContent = text
      return line
    }))
    this.resultTarget.classList.toggle("text-danger", over)
  }

  fill(text, values) {
    return Object.entries(values).reduce((out, [key, value]) =>
      out.replace(`%{${key}}`, typeof value === "number" ? this.pounds.format(value) : value), text)
  }
}
