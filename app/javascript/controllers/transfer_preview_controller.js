import { Controller } from "@hotwired/stimulus"

// «Trasladar café», written in gross pounds (client, 2026-10-30): how many
// gross pounds of the chosen state the chosen warehouse has, a warning (that
// does not stop it) when the transfer takes more, and the net pounds it
// moves (gross × that warehouse's net/gross proportion of the state), as a
// preview. The server repeats the net on save and its result is kept.
export default class extends Controller {
  static targets = ["from", "state", "gross", "net", "available", "overStock"]
  static values = { stock: Object, ratios: Object }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    const warehouse = this.fromTarget.value
    const state = this.stateTarget.value
    const available = parseFloat(this.stockValue[warehouse]?.[state] ?? 0)
    const gross = parseFloat(this.grossTarget.value)
    const ratio = parseFloat(this.ratiosValue[warehouse]?.[state])
    this.availableTarget.textContent = `${this.pounds.format(available)} lb`
    this.overStockTarget.hidden = !(gross > available)
    this.netTarget.textContent = gross > 0 && ratio > 0 ? `${this.pounds.format(Math.round(gross * ratio * 100) / 100)} lb` : "—"
  }
}
