import { Controller } from "@hotwired/stimulus"

// «Trasladar café»: how many net pounds of the chosen state the chosen
// warehouse has, and a warning (that does not stop it) when the transfer
// takes more. The server keeps the transfer as typed.
export default class extends Controller {
  static targets = ["from", "state", "net", "available", "overStock"]
  static values = { stock: Object }

  connect() {
    this.pounds = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.update()
  }

  update() {
    const available = parseFloat(this.stockValue[this.fromTarget.value]?.[this.stateTarget.value] ?? 0)
    const net = parseFloat(this.netTarget.value)
    this.availableTarget.textContent = `${this.pounds.format(available)} lb`
    this.overStockTarget.hidden = !(net > available)
  }
}
